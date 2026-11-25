// auth_screens.dart — written by APK Fact, NOT by the AI. Do not edit: it is replaced on every generation.
// Polished, tested sign-in for every mode of the pair (backend.dart kLoginMode): sign-in, new account, 6-digit code,
// forgotten password and the admin PIN. Colors and fonts come from the app's Theme, so it matches the app's design.
//
//   MaterialApp(
//     scaffoldMessengerKey: Backend.messengerKey,
//     theme: ..., darkTheme: ...,
//     home: AuthGate(
//       brand: const AuthBrand(name: 'اسم التطبيق', tagline: 'جملة قصيرة', icon: Icons.storefront_rounded),
//       home: const HomeScreen(),
//     ),
//   )
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'backend.dart';

/// The app's identity on the sign-in screens.
class AuthBrand {
  const AuthBrand({required this.name, this.tagline = '', this.icon = Icons.apps_rounded, this.logo});
  final String name;
  final String tagline;
  final IconData icon;

  /// Optional picture instead of the icon (e.g. Image.asset / Image.network).
  final Widget? logo;
}

/// Shows the sign-in screens while signed out and [home] once signed in (and, in the admin app, an admin).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.brand, required this.home});
  final AuthBrand brand;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Backend.session, Backend.profileChanged]),
      builder: (context, _) {
        final signedIn = Backend.session.value;
        final Widget child;
        if (!signedIn) {
          child = kLoginMode == 'none' ? _Starting(brand: brand) : _SignIn(brand: brand);
        } else if (kAppRole == 'admin' && !Backend.isAdmin) {
          child = _AdminPin(brand: brand);
        } else {
          child = home;
        }
        return AnimatedSwitcher(duration: const Duration(milliseconds: 280), child: KeyedSubtree(key: ValueKey(child.runtimeType), child: child));
      },
    );
  }
}

bool get _usesPhone => kLoginMode == 'phone_password' || kLoginMode == 'phone_email_code';
bool get _loginWithPhone => kLoginMode == 'phone_password';
bool get _usesEmail => kLoginMode != 'phone_password' && kLoginMode != 'none';
bool get _codeOnly => kLoginMode == 'code';
bool get _canReset => _usesEmail && !_codeOnly;

String? _required(String? v, String label) => (v == null || v.trim().isEmpty) ? 'اكتب $label' : null;

String? _validEmail(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return 'اكتب البريد الإلكتروني';
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(t) ? null : 'البريد الإلكتروني غير صحيح';
}

String? _validPhone(String? v) {
  final digits = (v ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.isEmpty) return 'اكتب رقم الهاتف';
  return digits.replaceAll('+', '').length >= 7 && digits.replaceAll('+', '').length <= 15 ? null : 'رقم الهاتف غير صحيح';
}

String? _validPassword(String? v) => (v ?? '').length < 6 ? 'كلمة المرور 6 أحرف على الأقل' : null;

/// Arabic and Persian digits typed on an Arabic keyboard become 0-9.
String _latinDigits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩', fa = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = ar.indexOf(ch), j = fa.indexOf(ch);
    b.write(i >= 0 ? '$i' : j >= 0 ? '$j' : ch);
  }
  return b.toString();
}

// ------------------------------------------------------------------ layout

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.brand, required this.title, this.subtitle = '', required this.children, this.back = false});
  final AuthBrand brand;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool back;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: back ? AppBar(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0) : null,
        body: SafeArea(
          // The first screen sits in the middle under the logo; the inner screens start at the top.
          child: Align(
            alignment: back ? Alignment.topCenter : Alignment.center,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!back) ...[
                      Center(child: _Logo(brand: brand)),
                      const SizedBox(height: 16),
                      Text(brand.name, textAlign: TextAlign.center, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      if (brand.tagline.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(brand.tagline, textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                      const SizedBox(height: 36),
                    ],
                    Text(title, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(subtitle, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.5)),
                    ],
                    const SizedBox(height: 24),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.brand});
  final AuthBrand brand;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [cs.primary, cs.tertiary]),
        boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: brand.logo ?? Icon(brand.icon, size: 42, color: cs.onPrimary),
    );
  }
}

class _Field extends StatefulWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboard,
    this.password = false,
    this.autofill,
    this.action = TextInputAction.next,
    this.onSubmit,
    this.ltr = false,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboard;
  final bool password;
  final Iterable<String>? autofill;
  final TextInputAction action;
  final VoidCallback? onSubmit;
  final bool ltr;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(16);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: widget.controller,
        validator: widget.validator,
        keyboardType: widget.keyboard,
        obscureText: widget.password && _hidden,
        autofillHints: widget.autofill,
        textInputAction: widget.action,
        onFieldSubmitted: (_) => widget.onSubmit?.call(),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        textDirection: widget.ltr ? TextDirection.ltr : null,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: Icon(widget.icon),
          suffixIcon: widget.password
              ? IconButton(
                  tooltip: _hidden ? 'إظهار' : 'إخفاء',
                  icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _hidden = !_hidden),
                )
              : null,
          filled: true,
          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.55),
          border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
          focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: cs.primary, width: 1.6)),
          errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: cs.error)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }
}

class _MainButton extends StatelessWidget {
  const _MainButton({required this.text, required this.busy, required this.onPressed});
  final String text;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        onPressed: busy ? null : onPressed,
        child: busy
            ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.6, color: cs.onPrimary))
            : Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.text);
  final String? text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: text == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(Icons.error_outline_rounded, color: cs.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(child: Text(text!, style: TextStyle(color: cs.onErrorContainer, height: 1.4))),
              ]),
            ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.lead, required this.action, required this.onTap});
  final String lead;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Wrap, not Row: on a narrow phone or with large system fonts the button goes to the next line.
    return Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Text(lead, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      TextButton(onPressed: onTap, child: Text(action, style: const TextStyle(fontWeight: FontWeight.w700))),
    ]);
  }
}

/// Runs a backend call with a busy state; shows its Arabic error. Returns true on success.
mixin _Busy<W extends StatefulWidget> on State<W> {
  bool busy = false;
  String? error;

  Future<bool> run(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      return true;
    } on BackendException catch (e) {
      if (mounted) setState(() => error = e.message);
      return false;
    } catch (_) {
      if (mounted) setState(() => error = 'حصل خطأ غير متوقع، حاول مرة ثانية.');
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

// ------------------------------------------------------------------ screens

class _SignIn extends StatefulWidget {
  const _SignIn({required this.brand});
  final AuthBrand brand;

  @override
  State<_SignIn> createState() => _SignInState();
}

class _SignInState extends State<_SignIn> with _Busy<_SignIn> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pw = TextEditingController();

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final id = _latinDigits(_id.text.trim());
    if (_codeOnly) {
      if (await run(() => Backend.sendLoginCode(id)) && mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => _Code(brand: widget.brand, email: id, signUp: false)));
      }
      return;
    }
    BackendException? notConfirmed;
    final ok = await run(() async {
      try {
        await Backend.signIn(email: _loginWithPhone ? null : id, phone: _loginWithPhone ? id : null, password: _pw.text);
      } on BackendException catch (e) {
        if (!e.needsCode) rethrow;
        notConfirmed = e;
        await Backend.resendSignUpCode(id);
      }
    });
    if (ok && notConfirmed != null && mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => _Code(brand: widget.brand, email: id, signUp: true)));
    }
    if (ok) TextInput.finishAutofillContext();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      brand: widget.brand,
      title: 'تسجيل الدخول',
      subtitle: _codeOnly ? 'اكتب بريدك ونرسل لك رمز دخول من 6 أرقام' : 'أهلاً بعودتك، سجّل دخولك للمتابعة',
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _ErrorBox(error),
              _loginWithPhone
                  ? _Field(controller: _id, label: 'رقم الهاتف', icon: Icons.phone_iphone_rounded, validator: _validPhone,
                      keyboard: TextInputType.phone, autofill: const [AutofillHints.telephoneNumber], ltr: true)
                  : _Field(controller: _id, label: 'البريد الإلكتروني', icon: Icons.alternate_email_rounded, validator: _validEmail,
                      keyboard: TextInputType.emailAddress, autofill: const [AutofillHints.email], ltr: true,
                      action: _codeOnly ? TextInputAction.done : TextInputAction.next, onSubmit: _codeOnly ? _submit : null),
              if (!_codeOnly)
                _Field(controller: _pw, label: 'كلمة المرور', icon: Icons.lock_outline_rounded, password: true,
                    validator: (v) => _required(v, 'كلمة المرور'), autofill: const [AutofillHints.password],
                    action: TextInputAction.done, onSubmit: _submit),
              if (!_codeOnly)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _Forgot(brand: widget.brand))),
                    child: const Text('نسيت كلمة المرور؟'),
                  ),
                ),
              const SizedBox(height: 8),
              _MainButton(text: _codeOnly ? 'أرسل الرمز' : 'دخول', busy: busy, onPressed: _submit),
              if (!_codeOnly) ...[
                const SizedBox(height: 16),
                _Link(
                  lead: 'ما عندك حساب؟',
                  action: 'إنشاء حساب جديد',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _SignUp(brand: widget.brand))),
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

class _SignUp extends StatefulWidget {
  const _SignUp({required this.brand});
  final AuthBrand brand;

  @override
  State<_SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<_SignUp> with _Busy<_SignUp> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _mail = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _phone, _mail, _pw, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final email = _mail.text.trim().toLowerCase();
    SignUpResult? result;
    final ok = await run(() async {
      result = await Backend.signUp(
        fullName: _name.text.trim(),
        phone: _usesPhone ? _latinDigits(_phone.text.trim()) : null,
        email: _usesEmail ? email : null,
        password: _pw.text,
      );
    });
    if (!ok || !mounted) return;
    TextInput.finishAutofillContext();
    if (result == SignUpResult.needsCode) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => _Code(brand: widget.brand, email: email, signUp: true)));
    } else {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      brand: widget.brand,
      back: true,
      title: 'إنشاء حساب جديد',
      subtitle: 'دقيقة واحدة وتكون جاهز',
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _ErrorBox(error),
              _Field(controller: _name, label: 'الاسم الكامل', icon: Icons.person_outline_rounded,
                  validator: (v) => (v ?? '').trim().length < 2 ? 'اكتب اسمك الكامل' : null,
                  keyboard: TextInputType.name, autofill: const [AutofillHints.name]),
              if (_usesPhone)
                _Field(controller: _phone, label: 'رقم الهاتف', icon: Icons.phone_iphone_rounded, validator: _validPhone,
                    keyboard: TextInputType.phone, autofill: const [AutofillHints.telephoneNumber], ltr: true),
              if (_usesEmail)
                _Field(controller: _mail, label: 'البريد الإلكتروني', icon: Icons.alternate_email_rounded, validator: _validEmail,
                    keyboard: TextInputType.emailAddress, autofill: const [AutofillHints.email], ltr: true),
              _Field(controller: _pw, label: 'كلمة المرور', icon: Icons.lock_outline_rounded, password: true,
                  validator: _validPassword, autofill: const [AutofillHints.newPassword]),
              _Field(controller: _pw2, label: 'تأكيد كلمة المرور', icon: Icons.lock_reset_rounded, password: true,
                  validator: (v) => v != _pw.text ? 'كلمتا المرور غير متطابقتين' : null,
                  autofill: const [AutofillHints.newPassword], action: TextInputAction.done, onSubmit: _submit),
              const SizedBox(height: 8),
              _MainButton(text: 'إنشاء الحساب', busy: busy, onPressed: _submit),
              const SizedBox(height: 16),
              _Link(lead: 'عندك حساب؟', action: 'تسجيل الدخول', onTap: () => Navigator.of(context).pop()),
            ]),
          ),
        ),
      ],
    );
  }
}

/// 6-digit code: confirms a new account (signUp) or signs in (code mode).
class _Code extends StatefulWidget {
  const _Code({required this.brand, required this.email, required this.signUp});
  final AuthBrand brand;
  final String email;
  final bool signUp;

  @override
  State<_Code> createState() => _CodeState();
}

class _CodeState extends State<_Code> with _Busy<_Code> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _wait = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _code.addListener(() => setState(() {}));
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _wait = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait = _wait > 0 ? _wait - 1 : 0);
      if (_wait == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _latinDigits(_code.text.trim());
    if (code.length != 6) {
      setState(() => error = 'اكتب الرمز كاملاً (6 أرقام)');
      return;
    }
    final ok = await run(() => widget.signUp ? Backend.verifySignUpCode(widget.email, code) : Backend.verifyLoginCode(widget.email, code));
    if (ok && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _resend() async {
    final ok = await run(() => widget.signUp ? Backend.resendSignUpCode(widget.email) : Backend.sendLoginCode(widget.email));
    if (ok) {
      _startTimer();
      Backend.toast('أرسلنا رمزاً جديداً');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final digits = _latinDigits(_code.text);
    return _AuthScaffold(
      brand: widget.brand,
      back: true,
      title: 'رمز التحقق',
      subtitle: 'أرسلنا رمزاً من 6 أرقام إلى\n${widget.email}',
      children: [
        _ErrorBox(error),
        GestureDetector(
          onTap: () => _focus.requestFocus(),
          child: Stack(children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  final filled = i < digits.length;
                  final active = i == digits.length && _focus.hasFocus;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 46,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: active || filled ? cs.primary : cs.outlineVariant, width: active ? 2 : 1.2),
                    ),
                    child: Text(filled ? digits[i] : '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  );
                }),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.01,
                child: TextField(
                  controller: _code,
                  focusNode: _focus,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹]'))],
                  decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                  onChanged: (v) {
                    if (_latinDigits(v).length == 6 && !busy) _verify();
                  },
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        _MainButton(text: 'تأكيد', busy: busy, onPressed: _verify),
        const SizedBox(height: 12),
        Center(
          child: _wait > 0
              ? Text('إعادة الإرسال بعد $_wait ثانية', style: TextStyle(color: cs.onSurfaceVariant))
              : TextButton.icon(onPressed: busy ? null : _resend, icon: const Icon(Icons.refresh_rounded), label: const Text('أرسل الرمز مرة ثانية')),
        ),
        const SizedBox(height: 4),
        Center(child: Text('ما وصلك؟ شوف مجلد الرسائل غير المرغوبة (Spam)', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
      ],
    );
  }
}

class _Forgot extends StatefulWidget {
  const _Forgot({required this.brand});
  final AuthBrand brand;

  @override
  State<_Forgot> createState() => _ForgotState();
}

class _ForgotState extends State<_Forgot> with _Busy<_Forgot> {
  final _form = GlobalKey<FormState>();
  final _mail = TextEditingController();
  final _code = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    for (final c in [_mail, _code, _pw, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    if (await run(() => Backend.sendPasswordReset(_mail.text.trim())) && mounted) setState(() => _sent = true);
  }

  Future<void> _reset() async {
    if (!_form.currentState!.validate()) return;
    final ok = await run(() => Backend.resetPassword(_mail.text.trim(), _latinDigits(_code.text.trim()), _pw.text));
    if (ok && mounted) {
      Backend.toast('تم تغيير كلمة المرور');
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canReset) {
      return _AuthScaffold(
        brand: widget.brand,
        back: true,
        title: 'نسيت كلمة المرور؟',
        subtitle: 'تواصل مع الإدارة عشان تغيّر كلمة المرور، وبعدها سجّل دخولك بالكلمة الجديدة.',
        children: [_MainButton(text: 'رجوع', busy: false, onPressed: () => Navigator.of(context).pop())],
      );
    }
    return _AuthScaffold(
      brand: widget.brand,
      back: true,
      title: 'استعادة كلمة المرور',
      subtitle: _sent ? 'اكتب الرمز اللي وصلك على بريدك وكلمة المرور الجديدة' : 'اكتب بريدك ونرسل لك رمزاً لتغيير كلمة المرور',
      children: [
        Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _ErrorBox(error),
            _Field(controller: _mail, label: 'البريد الإلكتروني', icon: Icons.alternate_email_rounded, validator: _validEmail,
                keyboard: TextInputType.emailAddress, autofill: const [AutofillHints.email], ltr: true,
                action: _sent ? TextInputAction.next : TextInputAction.done, onSubmit: _sent ? null : _send),
            if (_sent) ...[
              _Field(controller: _code, label: 'رمز التحقق (6 أرقام)', icon: Icons.pin_outlined,
                  validator: (v) => _latinDigits((v ?? '').trim()).length == 6 ? null : 'الرمز 6 أرقام',
                  keyboard: TextInputType.number, autofill: const [AutofillHints.oneTimeCode], ltr: true),
              _Field(controller: _pw, label: 'كلمة المرور الجديدة', icon: Icons.lock_outline_rounded, password: true,
                  validator: _validPassword, autofill: const [AutofillHints.newPassword]),
              _Field(controller: _pw2, label: 'تأكيد كلمة المرور', icon: Icons.lock_reset_rounded, password: true,
                  validator: (v) => v != _pw.text ? 'كلمتا المرور غير متطابقتين' : null, action: TextInputAction.done, onSubmit: _reset),
            ],
            const SizedBox(height: 8),
            _MainButton(text: _sent ? 'تغيير كلمة المرور' : 'أرسل الرمز', busy: busy, onPressed: _sent ? _reset : _send),
          ]),
        ),
      ],
    );
  }
}

/// Admin app: the signed-in user is not an admin yet (the owner set an admin PIN).
class _AdminPin extends StatefulWidget {
  const _AdminPin({required this.brand});
  final AuthBrand brand;

  @override
  State<_AdminPin> createState() => _AdminPinState();
}

class _AdminPinState extends State<_AdminPin> with _Busy<_AdminPin> {
  final _form = GlobalKey<FormState>();
  final _pin = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    // On success the profile says admin and AuthGate opens the admin home by itself.
    await run(() async {
      if (!await Backend.claimAdmin(_pin.text)) throw BackendException('رمز الإدارة غير صحيح');
    });
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      brand: widget.brand,
      title: 'دخول الإدارة',
      subtitle: 'اكتب رمز الإدارة اللي أعطاك له صاحب التطبيق',
      children: [
        Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _ErrorBox(error),
            _Field(controller: _pin, label: 'رمز الإدارة', icon: Icons.admin_panel_settings_outlined, password: true,
                validator: (v) => _required(v, 'رمز الإدارة'), action: TextInputAction.done, onSubmit: _submit, ltr: true),
            const SizedBox(height: 8),
            _MainButton(text: 'دخول', busy: busy, onPressed: _submit),
            const SizedBox(height: 8),
            TextButton(onPressed: busy ? null : Backend.signOut, child: const Text('تسجيل الخروج')),
          ]),
        ),
      ],
    );
  }
}

/// No-sign-in apps: the invisible session is being made (or failed: no network).
class _Starting extends StatefulWidget {
  const _Starting({required this.brand});
  final AuthBrand brand;

  @override
  State<_Starting> createState() => _StartingState();
}

class _StartingState extends State<_Starting> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 8), () {
      if (mounted && !Backend.signedIn) setState(() => _failed = true);
    });
  }

  Future<void> _retry() async {
    setState(() => _failed = false);
    await Backend.signOut(); // makes a new invisible session
    if (mounted && !Backend.signedIn) setState(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _Logo(brand: widget.brand),
            const SizedBox(height: 20),
            Text(widget.brand.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 28),
            if (!_failed)
              const CircularProgressIndicator()
            else ...[
              Text('ما في اتصال بالإنترنت', style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              FilledButton.icon(onPressed: _retry, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
            ],
          ]),
        ),
      ),
    );
  }
}
