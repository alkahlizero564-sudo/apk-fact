// ui_kit.dart — written by APK Fact, NOT by the AI. Do not edit: it is replaced on every generation.
// The app's design system: one polished theme and ready components, so every screen looks like a top store app and
// all screens match each other. Screens are composed from these; they do not draw buttons, fields or cards from
// scratch. Everything follows the app's Theme (its seed color, font, light / dark).
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

// ------------------------------------------------------------------ tokens

/// Spacing scale. Use these instead of random numbers.
class Gap {
  Gap._();
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32;
  static const SizedBox h4 = SizedBox(height: 4), h8 = SizedBox(height: 8), h12 = SizedBox(height: 12),
      h16 = SizedBox(height: 16), h24 = SizedBox(height: 24), h32 = SizedBox(height: 32);
  static const SizedBox w4 = SizedBox(width: 4), w8 = SizedBox(width: 8), w12 = SizedBox(width: 12), w16 = SizedBox(width: 16);
}

/// Corner radius scale.
class Radii {
  Radii._();
  static const double sm = 10, md = 14, lg = 20, xl = 28, pill = 999;
}

/// The app's personality (the owner picks it in APK Fact before the design):
///   luxe   — rich and premium: deep gradients, soft shadows, generous spacing, large radius;
///   simple — clear and easy: flat, high contrast, bigger text and tap targets, no gradients;
///   modern — fresh and light: tinted surfaces, subtle shadows, gradient accents.
enum KitStyle { luxe, simple, modern }

/// The font bundled into the app at build time (IBM Plex Sans Arabic / Almarai / Tajawal by style). When it is not
/// bundled, Flutter falls back to the system font by itself.
const String kAppFont = 'AppFont';

/// Style details every component reads (Kit.of(context)).
class Kit extends ThemeExtension<Kit> {
  const Kit({required this.style, required this.radius, required this.shadow, required this.gradient, required this.border, required this.scale});
  final KitStyle style;
  final double radius; // cards
  final bool shadow;
  final bool gradient;
  final bool border;
  final double scale; // text / spacing scale (simple: bigger)

  static Kit of(BuildContext context) =>
      Theme.of(context).extension<Kit>() ?? const Kit(style: KitStyle.modern, radius: 20, shadow: true, gradient: true, border: true, scale: 1);

  /// The decoration of a card in this style.
  BoxDecoration card(ColorScheme cs, {Color? color, bool dark = false}) => BoxDecoration(
        color: color ?? (dark ? cs.surfaceContainerHigh : cs.surface),
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: cs.outlineVariant.withValues(alpha: dark ? 0.3 : 0.5)) : null,
        boxShadow: shadow && !dark
            ? [
                BoxShadow(color: cs.shadow.withValues(alpha: style == KitStyle.luxe ? 0.10 : 0.06), blurRadius: style == KitStyle.luxe ? 24 : 14, offset: const Offset(0, 6)),
              ]
            : null,
      );

  /// The brand gradient (headers, banners, primary highlights). Always deep enough for white text on it: in dark
  /// mode the primary color is a light pastel, so the gradient is built from the deep containers instead.
  LinearGradient brand(ColorScheme cs) {
    final dark = cs.brightness == Brightness.dark;
    final a = dark ? Color.lerp(cs.primaryContainer, Colors.black, 0.1)! : cs.primary;
    final mix = style == KitStyle.luxe ? 0.3 : 0.7; // luxe stays on the brand color
    final b = dark ? Color.lerp(cs.primaryContainer, cs.tertiaryContainer, mix)! : Color.lerp(cs.primary, cs.tertiary, mix)!;
    return LinearGradient(
      begin: AlignmentDirectional.topStart,
      end: AlignmentDirectional.bottomEnd,
      colors: style == KitStyle.luxe ? [Color.lerp(a, Colors.black, 0.3)!, a, b] : [a, b],
    );
  }

  /// A deep version of [c] for white text (banner slides): c itself in light mode, darker in dark mode.
  Color deep(ColorScheme cs, Color c) => cs.brightness == Brightness.dark ? Color.lerp(c, Colors.black, 0.62)! : c;

  @override
  Kit copyWith({KitStyle? style, double? radius, bool? shadow, bool? gradient, bool? border, double? scale}) => Kit(
      style: style ?? this.style, radius: radius ?? this.radius, shadow: shadow ?? this.shadow, gradient: gradient ?? this.gradient,
      border: border ?? this.border, scale: scale ?? this.scale);

  @override
  Kit lerp(ThemeExtension<Kit>? other, double t) => t < 0.5 ? this : (other as Kit? ?? this);
}

/// The whole app's theme from the design's main color. Use it for theme AND darkTheme:
///   theme: appTheme(seed: const Color(0xFF0F766E), style: KitStyle.modern),
///   darkTheme: appTheme(seed: ..., style: ..., brightness: Brightness.dark)
ThemeData appTheme({required Color seed, KitStyle style = KitStyle.modern, Brightness brightness = Brightness.light, String? fontFamily = kAppFont, Color? secondary}) {
  final cs = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    secondary: secondary,
    // fidelity keeps the brand color as rich as the design's (luxe, simple); tonalSpot is softer (modern).
    dynamicSchemeVariant: style == KitStyle.modern ? DynamicSchemeVariant.tonalSpot : DynamicSchemeVariant.fidelity,
  );
  final dark = brightness == Brightness.dark;
  final kit = switch (style) {
    KitStyle.luxe => const Kit(style: KitStyle.luxe, radius: 24, shadow: true, gradient: true, border: false, scale: 1),
    KitStyle.simple => const Kit(style: KitStyle.simple, radius: 14, shadow: false, gradient: false, border: true, scale: 1.08),
    KitStyle.modern => const Kit(style: KitStyle.modern, radius: 20, shadow: true, gradient: true, border: true, scale: 1),
  };
  var base = ThemeData(useMaterial3: true, colorScheme: cs, brightness: brightness, fontFamily: fontFamily);
  if (kit.scale != 1) {
    base = base.copyWith(textTheme: base.textTheme.apply(fontSizeFactor: kit.scale));
  }
  final field = OutlineInputBorder(borderRadius: BorderRadius.circular(kit.radius * 0.7), borderSide: BorderSide.none);
  return base.copyWith(
    extensions: [kit],
    scaffoldBackgroundColor: dark ? cs.surface : Color.alphaBlend(cs.primary.withValues(alpha: 0.025), cs.surface),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: cs.onSurface,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface),
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: dark ? cs.surfaceContainerHigh : cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kit.radius),
        side: kit.border ? BorderSide(color: cs.outlineVariant.withValues(alpha: dark ? 0.35 : 0.55)) : BorderSide.none,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: dark ? 0.6 : 0.5),
      border: field,
      enabledBorder: field.copyWith(borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45))),
      focusedBorder: field.copyWith(borderSide: BorderSide(color: cs.primary, width: 1.6)),
      errorBorder: field.copyWith(borderSide: BorderSide(color: cs.error)),
      contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.lg),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: Size(64, style == KitStyle.simple ? 56 : 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(style == KitStyle.luxe ? Radii.pill : kit.radius * 0.7)),
        textStyle: TextStyle(fontSize: 15.5 * kit.scale, fontWeight: FontWeight.w700, fontFamily: fontFamily),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(64, style == KitStyle.simple ? 56 : 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(style == KitStyle.luxe ? Radii.pill : kit.radius * 0.7)),
        side: BorderSide(color: cs.outlineVariant),
        textStyle: TextStyle(fontSize: 15.5 * kit.scale, fontWeight: FontWeight.w700, fontFamily: fontFamily),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill)),
      side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: dark ? cs.surfaceContainer : cs.surface,
      indicatorColor: cs.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
      backgroundColor: dark ? cs.surfaceContainerHigh : cs.surface,
    ),
    dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl))),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
    ),
    dividerTheme: DividerThemeData(color: cs.outlineVariant.withValues(alpha: 0.4), space: 1),
    listTileTheme: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md))),
  );
}

// ------------------------------------------------------------------ formatting

/// 12500 -> "12,500 ج.س". Use for every price / total / fee; null -> "—".
String money(Object? value, {String currency = 'ج.س', int decimals = 0}) {
  if (value == null || '$value'.isEmpty) return '—';
  final n = value is num ? value : num.tryParse('$value');
  if (n == null) return '$value';
  final fixed = n.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final intPart = parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return '${parts.length > 1 ? '$intPart.${parts[1]}' : intPart} $currency';
}

/// An ISO date from the database -> "قبل 5 دقائق" / "أمس" / "12/3/2026".
String dateText(Object? iso) {
  final d = iso is DateTime ? iso : DateTime.tryParse('${iso ?? ''}');
  if (d == null) return '—';
  final diff = DateTime.now().difference(d.toLocal());
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
  if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
  if (diff.inDays == 1) return 'أمس';
  if (diff.inDays < 7) return 'قبل ${diff.inDays} أيام';
  final l = d.toLocal();
  return '${l.day}/${l.month}/${l.year}';
}

// ------------------------------------------------------------------ page

/// A screen: big title, optional subtitle and actions, pull to refresh, safe padding. Use it for every screen.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.floating,
    this.bottom,
    this.onRefresh,
    this.back = false,
  });
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final Widget? floating;
  final Widget? bottom;
  final Future<void> Function()? onRefresh;

  /// true for a screen opened on top of another (shows the back arrow).
  final bool back;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    Widget content = body;
    if (onRefresh != null) content = RefreshIndicator(onRefresh: onRefresh!, child: content);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: back,
          toolbarHeight: subtitle == null ? 64 : 76,
          title: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface)),
            if (subtitle != null)
              Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
          ]),
          actions: [...actions, const SizedBox(width: Gap.sm)],
        ),
        floatingActionButton: floating,
        bottomNavigationBar: bottom,
        body: SafeArea(top: false, child: content),
      ),
    );
  }
}

/// Title of a group of items, with an optional action on the other side ("عرض الكل").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.padding = const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, Gap.sm)});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ]),
    );
  }
}

// ------------------------------------------------------------------ buttons and fields

enum ButtonKind { primary, secondary, outline, text, danger }

/// The only button style of the app. busy: shows a spinner and blocks double taps. expand: full width.
class AppButton extends StatelessWidget {
  const AppButton(this.label, {super.key, required this.onPressed, this.icon, this.kind = ButtonKind.primary, this.busy = false, this.expand = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonKind kind;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = switch (kind) {
      ButtonKind.primary => cs.onPrimary,
      ButtonKind.danger => cs.onError,
      ButtonKind.secondary => cs.onSecondaryContainer,
      _ => cs.primary,
    };
    final child = busy
        ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 20), Gap.w8],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ]);
    final tap = busy ? null : onPressed;
    final Widget button = switch (kind) {
      ButtonKind.primary => FilledButton(onPressed: tap, child: child),
      ButtonKind.danger => FilledButton(style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError), onPressed: tap, child: child),
      ButtonKind.secondary => FilledButton.tonal(onPressed: tap, child: child),
      ButtonKind.outline => OutlinedButton(onPressed: tap, child: child),
      ButtonKind.text => TextButton(onPressed: tap, child: child),
    };
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// The only text field style of the app (with label, icon, validation, number / phone keyboards, multi-line).
class AppField extends StatefulWidget {
  const AppField({
    super.key,
    required this.label,
    this.controller,
    this.icon,
    this.hint,
    this.validator,
    this.keyboard,
    this.password = false,
    this.lines = 1,
    this.onChanged,
    this.initial,
    this.ltr = false,
    this.action = TextInputAction.next,
  });
  final String label;
  final TextEditingController? controller;
  final IconData? icon;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboard;
  final bool password;
  final int lines;
  final ValueChanged<String>? onChanged;
  final String? initial;
  final bool ltr;
  final TextInputAction action;

  @override
  State<AppField> createState() => _AppFieldState();
}

class _AppFieldState extends State<AppField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: TextFormField(
        controller: widget.controller,
        initialValue: widget.controller == null ? widget.initial : null,
        validator: widget.validator,
        keyboardType: widget.lines > 1 ? TextInputType.multiline : widget.keyboard,
        obscureText: widget.password && _hidden,
        minLines: widget.lines > 1 ? widget.lines : null,
        maxLines: widget.password ? 1 : widget.lines,
        onChanged: widget.onChanged,
        textInputAction: widget.lines > 1 ? TextInputAction.newline : widget.action,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        textDirection: widget.ltr ? TextDirection.ltr : null,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          prefixIcon: widget.icon == null ? null : Icon(widget.icon),
          alignLabelWithHint: widget.lines > 1,
          suffixIcon: widget.password
              ? IconButton(
                  icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _hidden = !_hidden),
                )
              : null,
        ),
      ),
    );
  }
}

/// Search box for lists.
class AppSearch extends StatelessWidget {
  const AppSearch({super.key, required this.onChanged, this.hint = 'ابحث…'});
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.sm),
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(hintText: hint, prefixIcon: const Icon(Icons.search_rounded), isDense: true),
      ),
    );
  }
}

/// A row of choices (categories, status filter). selected is the chosen value ('' = all).
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({super.key, required this.options, required this.selected, required this.onSelected, this.allLabel = 'الكل'});

  /// value -> label.
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final String? allLabel;

  @override
  Widget build(BuildContext context) {
    final items = {if (allLabel != null) '': allLabel!, ...options};
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        children: [
          for (final e in items.entries)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: Gap.sm),
              child: ChoiceChip(label: Text(e.value), selected: selected == e.key, onSelected: (_) => onSelected(e.key)),
            ),
        ],
      ),
    );
  }
}

/// - 1 + quantity control.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 999});
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget btn(IconData i, int to, bool on) => IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          onPressed: on ? () => onChanged(to) : null,
          icon: Icon(i, size: 18),
        );
    return Container(
      decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(Radii.pill)),
      padding: const EdgeInsets.all(2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(Icons.remove_rounded, value - 1, value > min),
        SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
        btn(Icons.add_rounded, value + 1, value < max),
      ]),
    );
  }
}

// ------------------------------------------------------------------ cards and rows

/// The only card style of the app.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(Gap.lg), this.margin = const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm), this.color});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kit = Kit.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: kit.card(cs, color: color, dark: dark),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(kit.radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      ),
    );
  }
}

/// A list row: leading icon / image / avatar, title, subtitle, trailing (badge, price, chevron).
class AppTile extends StatelessWidget {
  const AppTile({super.key, required this.title, this.subtitle, this.icon, this.image, this.trailing, this.onTap, this.dense = false});
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? image;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    Widget? lead;
    if (image != null && image!.isNotEmpty) {
      lead = AppImage(image, width: 52, height: 52, radius: Radii.sm);
    } else if (icon != null) {
      lead = Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(Radii.sm)),
        child: Icon(icon, color: cs.onPrimaryContainer),
      );
    }
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Gap.lg, vertical: dense ? Gap.sm : Gap.md),
        child: Row(children: [
          if (lead != null) ...[lead, Gap.w12],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                Gap.h4,
                Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ]),
          ),
          if (trailing != null) ...[Gap.w8, trailing!] else if (onTap != null) Icon(Icons.chevron_left_rounded, color: cs.onSurfaceVariant),
        ]),
      ),
    );
  }
}

/// A product / item card for grids (GridView with crossAxisCount: 2, childAspectRatio: 0.62) or ProductRow.
/// oldPrice shows a struck-through price and a discount badge; rating (0-5) shows stars; soldOut greys it out.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.title, this.image, this.price, this.oldPrice, this.subtitle, this.badge, this.rating, this.soldOut = false, this.onTap, this.onAdd, this.favorite, this.onFavorite});
  final String title;
  final String? image;
  final Object? price;
  final Object? oldPrice;
  final String? subtitle;
  final String? badge;
  final num? rating;
  final bool soldOut;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final bool? favorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final kit = Kit.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final now = num.tryParse('${price ?? ''}');
    final before = num.tryParse('${oldPrice ?? ''}');
    final off = (now != null && before != null && before > now) ? ((before - now) * 100 / before).round() : null;
    return DecoratedBox(
      decoration: kit.card(cs, dark: dark),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(kit.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(Gap.sm),
                child: Stack(fit: StackFit.expand, children: [
                  Opacity(opacity: soldOut ? 0.45 : 1, child: AppImage(image, radius: kit.radius - Gap.sm)),
                  if (off != null || badge != null || soldOut)
                    PositionedDirectional(
                      top: Gap.sm,
                      start: Gap.sm,
                      child: _Pill(soldOut ? 'نفد' : off != null ? '-$off%' : badge!, color: soldOut ? cs.outline : off != null ? cs.error : cs.primary),
                    ),
                  if (onFavorite != null)
                    PositionedDirectional(
                      top: Gap.xs,
                      end: Gap.xs,
                      child: Material(
                        color: cs.surface.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: onFavorite,
                          icon: Icon(favorite == true ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 19,
                              color: favorite == true ? cs.error : cs.onSurfaceVariant),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, Gap.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (subtitle != null)
                  Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.35)),
                if (rating != null) ...[Gap.h4, RatingStars(rating!, size: 13)],
                Gap.h8,
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: PriceTag(price, oldPrice: off != null ? oldPrice : null)),
                  if (onAdd != null && !soldOut)
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton.filled(padding: EdgeInsets.zero, onPressed: onAdd, icon: const Icon(Icons.add_rounded, size: 20)),
                    ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.pill)),
        child: Text(text, textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
      );
}

/// A price, with the old price struck through next to it when there is a discount.
class PriceTag extends StatelessWidget {
  const PriceTag(this.price, {super.key, this.oldPrice, this.large = false});
  final Object? price;
  final Object? oldPrice;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 6, children: [
      Text(money(price), style: (large ? tt.headlineSmall : tt.titleSmall)?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
      if (oldPrice != null)
        Text(money(oldPrice), style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, decoration: TextDecoration.lineThrough)),
    ]);
  }
}

/// 0-5 stars (halves too) with an optional count: RatingStars(4.5, count: 120).
class RatingStars extends StatelessWidget {
  const RatingStars(this.value, {super.key, this.count, this.size = 16});
  final num value;
  final int? count;
  final double size;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFF5A524);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        Icon(value >= i ? Icons.star_rounded : value >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded, size: size, color: gold),
      Gap.w4,
      Text(count == null ? value.toStringAsFixed(1) : '${value.toStringAsFixed(1)} ($count)',
          style: TextStyle(fontSize: size * 0.8, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }
}

/// A number on a dashboard (orders today, sales, customers).
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, this.icon = Icons.insights_rounded, this.note, this.onTap});
  final String label;
  final String value;
  final IconData icon;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(Gap.sm),
              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(Radii.sm)),
              child: Icon(icon, size: 20, color: cs.onPrimaryContainer),
            ),
            Gap.h12,
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            Gap.h4,
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            if (note != null) ...[Gap.h4, Text(note!, style: tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700))],
          ]),
        ),
      ),
    );
  }
}

enum Tone { success, warning, danger, info, neutral }

/// The tone that fits a status word (Arabic or English): delivered/paid -> success, pending -> warning, ...
Tone toneOf(Object? status) {
  final s = '${status ?? ''}'.toLowerCase();
  if (RegExp(r'(deliver|done|complet|paid|approv|accept|active|confirm|تم|مكتمل|مدفوع|مقبول|مؤكد|نشط|تسليم)').hasMatch(s)) return Tone.success;
  if (RegExp(r'(cancel|reject|fail|declin|expired|ملغ|مرفوض|فشل|منتهي)').hasMatch(s)) return Tone.danger;
  if (RegExp(r'(pend|wait|review|new|process|بانتظار|قيد|جديد|مراجعة|معالجة)').hasMatch(s)) return Tone.warning;
  if (RegExp(r'(ship|way|prepar|الطريق|تجهيز|شحن)').hasMatch(s)) return Tone.info;
  return Tone.neutral;
}

/// A small colored label for a status ("قيد المراجعة", "تم التسليم"). tone defaults to toneOf(text).
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.text, {super.key, this.tone});
  final String text;
  final Tone? tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = switch (tone ?? toneOf(text)) {
      Tone.success => const Color(0xFF16A34A),
      Tone.warning => const Color(0xFFD97706),
      Tone.danger => cs.error,
      Tone.info => cs.primary,
      Tone.neutral => cs.outline,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: base.withValues(alpha: dark ? 0.22 : 0.12), borderRadius: BorderRadius.circular(Radii.pill)),
      child: Text(text, style: TextStyle(color: dark ? Color.lerp(base, Colors.white, 0.35) : base, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// A network picture with a soft placeholder while loading and an icon when missing or broken.
class AppImage extends StatelessWidget {
  const AppImage(this.url, {super.key, this.width, this.height, this.radius = Radii.md, this.fit = BoxFit.cover});
  final String? url;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final empty = Container(
      width: width,
      height: height,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Icon(Icons.image_outlined, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
    );
    final u = url ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: u.startsWith('http')
          ? Image.network(u, width: width, height: height, fit: fit,
              loadingBuilder: (c, child, p) => p == null ? child : empty,
              errorBuilder: (c, e, s) => empty)
          : empty,
    );
  }
}

/// A round picture or the initials of a name.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, this.name = '', this.url, this.size = 44});
  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (url != null && url!.startsWith('http')) {
      return ClipOval(child: AppImage(url, width: size, height: size, radius: size));
    }
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final initials = words.take(2).map((w) => w.characters.first).join();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: cs.primaryContainer,
      child: Text(initials.isEmpty ? '؟' : initials, style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w800)),
    );
  }
}

/// Key / value line in a details card ("رقم الطلب" — "#1024").
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.strong = false});
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: cs.onSurfaceVariant))),
        Text(value, style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w600, fontSize: strong ? 16 : 14)),
      ]),
    );
  }
}

// ------------------------------------------------------------------ states

/// Nothing to show yet: an icon, a title, a short hint and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.message, this.icon = Icons.inbox_outlined, this.action, this.onAction});
  final String title;
  final String? message;
  final IconData icon;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(Gap.xl),
            decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.5), shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: cs.primary),
          ),
          Gap.h16,
          Text(title, textAlign: TextAlign.center, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          if (message != null) ...[
            Gap.h8,
            Text(message!, textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.5)),
          ],
          if (action != null) ...[Gap.h16, AppButton(action!, onPressed: onAction, kind: ButtonKind.secondary)],
        ]),
      ),
    );
  }
}

/// Grey placeholder rows while a list loads for the first time.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    Widget bar(double w, double h) => Container(width: w, height: h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)));
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
        child: Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(Radii.sm))),
          Gap.w12,
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar(160, 14), Gap.h8, bar(100, 12)])),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ dialogs and sheets

/// Asks before an important action. Returns true when confirmed.
Future<bool> confirmAction(BuildContext context, {required String title, String? message, String confirm = 'تأكيد', bool danger = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          AppButton('إلغاء', kind: ButtonKind.text, onPressed: () => Navigator.of(c).pop(false)),
          AppButton(confirm, kind: danger ? ButtonKind.danger : ButtonKind.primary, onPressed: () => Navigator.of(c).pop(true)),
        ],
      ),
    ),
  );
  return ok == true;
}

/// A bottom sheet with a title (forms, filters, choices).
Future<T?> showAppSheet<T>(BuildContext context, {required String title, required Widget child}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, MediaQuery.of(c).viewInsets.bottom + Gap.lg),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Gap.h16,
          Flexible(child: SingleChildScrollView(child: child)),
        ]),
      ),
    ),
  );
}

// ------------------------------------------------------------------ premium sections

/// The top of a home screen: brand gradient (or a clean surface in the simple style), greeting, avatar, actions and
/// an optional search box over its bottom edge. Put it first in a home ListView (not inside an AppPage AppBar).
class HeroHeader extends StatelessWidget {
  const HeroHeader({super.key, required this.title, this.greeting, this.subtitle, this.avatarName, this.avatarUrl, this.actions = const [], this.onSearch, this.searchHint = 'ابحث…', this.onSearchTap});
  final String title;
  final String? greeting;
  final String? subtitle;
  final String? avatarName;
  final String? avatarUrl;
  final List<Widget> actions;
  final ValueChanged<String>? onSearch;
  final String searchHint;

  /// Instead of typing here: open a search screen.
  final VoidCallback? onSearchTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final kit = Kit.of(context);
    final onBrand = kit.gradient ? Colors.white : cs.onSurface;
    final hasSearch = onSearch != null || onSearchTap != null;
    return Padding(
      padding: EdgeInsets.only(bottom: hasSearch ? 28 : Gap.sm),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(Gap.xl, MediaQuery.paddingOf(context).top + Gap.lg, Gap.xl, hasSearch ? 52 : Gap.xl),
          decoration: BoxDecoration(
            gradient: kit.gradient ? kit.brand(cs) : null,
            color: kit.gradient ? null : cs.surface,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(kit.radius + 8)),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              if (avatarName != null || avatarUrl != null) ...[
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: onBrand.withValues(alpha: 0.6), width: 2)),
                  child: AppAvatar(name: avatarName ?? '', url: avatarUrl, size: 46),
                ),
                Gap.w12,
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (greeting != null) Text(greeting!, style: tt.bodyMedium?.copyWith(color: onBrand.withValues(alpha: 0.8))),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.headlineSmall?.copyWith(color: onBrand, fontWeight: FontWeight.w800)),
                  if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall?.copyWith(color: onBrand.withValues(alpha: 0.75))),
                ]),
              ),
              ...actions.map((a) => IconTheme(data: IconThemeData(color: onBrand), child: a)),
            ]),
          ),
        ),
        if (hasSearch)
          PositionedDirectional(
            start: Gap.lg,
            end: Gap.lg,
            bottom: -26,
            child: Material(
              elevation: kit.style == KitStyle.simple ? 0 : 6,
              shadowColor: cs.shadow.withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kit.radius * 0.8),
                side: kit.style == KitStyle.simple ? BorderSide(color: cs.outline.withValues(alpha: 0.6)) : BorderSide.none,
              ),
              color: Theme.of(context).brightness == Brightness.dark ? cs.surfaceContainerHigh : cs.surface,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: TextField(
                  readOnly: onSearchTap != null,
                  onTap: onSearchTap,
                  onChanged: onSearch,
                  decoration: InputDecoration(
                    hintText: searchHint,
                    prefixIcon: Icon(Icons.search_rounded, color: cs.primary),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// One slide of PromoCarousel.
class Promo {
  const Promo({required this.title, this.subtitle, this.action, this.image, this.icon = Icons.local_offer_rounded, this.onTap});
  final String title;
  final String? subtitle;
  final String? action;
  final String? image;
  final IconData icon;
  final VoidCallback? onTap;
}

/// Sliding offer banners with page dots (auto-plays). Slides come from the data (e.g. an offers table), not the code.
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key, required this.items, this.height = 156});
  final List<Promo> items;
  final double height;

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  final _pc = PageController(viewportFraction: 0.9);
  int _page = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 5), _next);
  }

  void _next() {
    if (!mounted || widget.items.length < 2) return;
    if (_pc.hasClients) {
      _pc.animateToPage((_page + 1) % widget.items.length, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    }
    Future<void>.delayed(const Duration(seconds: 5), _next);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final kit = Kit.of(context);
    return Column(children: [
      SizedBox(
        height: widget.height,
        child: PageView.builder(
          controller: _pc,
          itemCount: widget.items.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) {
            final p = widget.items[i];
            final tint = kit.deep(cs, [cs.primary, cs.tertiary, cs.secondary][i % 3]);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
              child: Material(
                borderRadius: BorderRadius.circular(kit.radius),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: p.onTap,
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: kit.gradient
                          ? LinearGradient(colors: [tint, Color.lerp(tint, Colors.black, 0.25)!], begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd)
                          : null,
                      color: kit.gradient ? null : cs.primaryContainer,
                    ),
                    child: Stack(children: [
                      if (p.image != null && p.image!.startsWith('http'))
                        Positioned.fill(child: Opacity(opacity: 0.35, child: AppImage(p.image, radius: 0))),
                      PositionedDirectional(
                        end: -18,
                        bottom: -18,
                        child: Icon(p.icon, size: 120, color: (kit.gradient ? Colors.white : cs.primary).withValues(alpha: 0.14)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(Gap.xl),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(p.title, maxLines: 2, style: tt.titleLarge?.copyWith(color: kit.gradient ? Colors.white : cs.onPrimaryContainer, fontWeight: FontWeight.w800)),
                            if (p.subtitle != null) ...[
                              Gap.h4,
                              Text(p.subtitle!, maxLines: 2, style: tt.bodyMedium?.copyWith(color: (kit.gradient ? Colors.white : cs.onPrimaryContainer).withValues(alpha: 0.85))),
                            ],
                            if (p.action != null) ...[
                              Gap.h12,
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(color: kit.gradient ? Colors.white : cs.primary, borderRadius: BorderRadius.circular(Radii.pill)),
                                child: Text(p.action!, style: TextStyle(color: kit.gradient ? tint : cs.onPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                              ),
                            ],
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      if (widget.items.length > 1) ...[
        Gap.h12,
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < widget.items.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _page ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(color: i == _page ? cs.primary : cs.outlineVariant, borderRadius: BorderRadius.circular(Radii.pill)),
            ),
        ]),
      ],
    ]);
  }
}

/// One category of CategoryGrid.
class CategoryItem {
  const CategoryItem({required this.label, required this.icon, this.onTap, this.selected = false});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool selected;
}

/// Round category icons in a horizontal row (or a 4-column grid with wrap: true).
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key, required this.items, this.wrap = false});
  final List<CategoryItem> items;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kit = Kit.of(context);
    Widget one(CategoryItem c) => SizedBox(
          width: 78,
          child: InkWell(
            onTap: c.onTap,
            borderRadius: BorderRadius.circular(Radii.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.xs),
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: c.selected && kit.gradient ? kit.brand(cs) : null,
                    color: c.selected ? (kit.gradient ? null : cs.primary) : cs.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(kit.style == KitStyle.luxe ? 29 : kit.radius * 0.8),
                  ),
                  child: Icon(c.icon, color: c.selected ? cs.onPrimary : cs.primary, size: 26),
                ),
                Gap.h8,
                Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, fontWeight: c.selected ? FontWeight.w800 : FontWeight.w600)),
              ]),
            ),
          ),
        );
    if (wrap) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md),
        child: Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: Gap.md, children: items.map(one).toList()),
      );
    }
    return SizedBox(
      height: 100,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: Gap.md), children: items.map(one).toList()),
    );
  }
}

/// A horizontal row of ProductCards ("الأكثر طلباً", "وصل حديثاً").
class ProductRow extends StatelessWidget {
  const ProductRow({super.key, required this.children, this.height = 276, this.itemWidth = 168});
  final List<Widget> children;
  final double height;
  final double itemWidth;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.xs),
          itemCount: children.length,
          separatorBuilder: (_, __) => Gap.w12,
          itemBuilder: (_, i) => SizedBox(width: itemWidth, child: children[i]),
        ),
      );
}

/// One step of OrderTimeline.
class TrackStep {
  const TrackStep(this.title, {this.time, this.icon = Icons.check_rounded});
  final String title;
  final String? time;
  final IconData icon;
}

/// Order tracking: the steps in order, done up to [current] (index), the current one highlighted.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.steps, required this.current, this.cancelled = false});
  final List<TrackStep> steps;
  final int current;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(children: [
      for (var i = 0; i < steps.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 36,
              child: Column(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < current ? cs.primary : i == current ? (cancelled ? cs.error : cs.primary) : cs.surfaceContainerHighest,
                    boxShadow: i == current && !cancelled ? [BoxShadow(color: cs.primary.withValues(alpha: 0.35), blurRadius: 10)] : null,
                  ),
                  child: Icon(i == current && cancelled ? Icons.close_rounded : steps[i].icon, size: 16,
                      color: i <= current ? cs.onPrimary : cs.onSurfaceVariant),
                ),
                if (i < steps.length - 1)
                  Expanded(child: Container(width: 2.5, margin: const EdgeInsets.symmetric(vertical: 2), color: i < current ? cs.primary : cs.outlineVariant)),
              ]),
            ),
            Gap.w12,
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: Gap.lg),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(steps[i].title, style: tt.titleSmall?.copyWith(
                      fontWeight: i == current ? FontWeight.w800 : FontWeight.w600,
                      color: i <= current ? cs.onSurface : cs.onSurfaceVariant)),
                  if (steps[i].time != null) Text(steps[i].time!, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}

/// The top of a profile screen: avatar, name, a line under it and small numbers (orders, points...).
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.name, this.subtitle, this.avatarUrl, this.stats = const {}, this.onEdit});
  final String name;
  final String? subtitle;
  final String? avatarUrl;

  /// label -> value, e.g. {'طلباتي': '12', 'المفضلة': '8'}.
  final Map<String, String> stats;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final kit = Kit.of(context);
    final onBrand = kit.gradient ? Colors.white : cs.onSurface;
    return Container(
      margin: const EdgeInsets.all(Gap.lg),
      padding: const EdgeInsets.all(Gap.xl),
      decoration: kit.gradient
          ? BoxDecoration(gradient: kit.brand(cs), borderRadius: BorderRadius.circular(kit.radius + 4))
          : kit.card(cs, dark: Theme.of(context).brightness == Brightness.dark),
      child: Column(children: [
        Row(children: [
          AppAvatar(name: name, url: avatarUrl, size: 64),
          Gap.w16,
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isEmpty ? 'حسابي' : name, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.titleLarge?.copyWith(color: onBrand, fontWeight: FontWeight.w800, height: 1.3)),
              if (subtitle != null) Text(subtitle!, style: tt.bodyMedium?.copyWith(color: onBrand.withValues(alpha: 0.8))),
            ]),
          ),
          if (onEdit != null) IconButton(onPressed: onEdit, icon: Icon(Icons.edit_rounded, color: onBrand)),
        ]),
        if (stats.isNotEmpty) ...[
          Gap.h16,
          Container(
            padding: const EdgeInsets.symmetric(vertical: Gap.md),
            decoration: BoxDecoration(color: onBrand.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(Radii.md)),
            child: Row(children: [
              for (final e in stats.entries)
                Expanded(
                  child: Column(children: [
                    Text(e.value, style: tt.titleLarge?.copyWith(color: onBrand, fontWeight: FontWeight.w800)),
                    Text(e.key, style: tt.bodySmall?.copyWith(color: onBrand.withValues(alpha: 0.8))),
                  ]),
                ),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// A rounded group of settings / menu rows with a title (like the best apps' "Account" / "Support" sections).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kit = Kit.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, Gap.sm, Gap.sm),
            child: Text(title!, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          ),
        DecoratedBox(
          decoration: kit.card(cs, dark: Theme.of(context).brightness == Brightness.dark),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(kit.radius),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) const Divider(height: 1, indent: 60),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

/// One row of SettingsGroup: colored icon, title, optional value / switch, chevron.
class SettingsTile extends StatelessWidget {
  const SettingsTile({super.key, required this.title, required this.icon, this.value, this.onTap, this.danger = false, this.switchValue, this.onSwitch});
  final String title;
  final IconData icon;
  final String? value;
  final VoidCallback? onTap;
  final bool danger;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = danger ? cs.error : cs.primary;
    return InkWell(
      onTap: onTap ?? (onSwitch != null ? () => onSwitch!(!(switchValue ?? false)) : null),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.sm)),
            child: Icon(icon, size: 19, color: color),
          ),
          Gap.w12,
          Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: danger ? cs.error : null))),
          if (value != null) Text(value!, style: TextStyle(color: cs.onSurfaceVariant)),
          if (switchValue != null)
            Switch(value: switchValue!, onChanged: onSwitch)
          else if (!danger)
            Icon(Icons.chevron_left_rounded, color: cs.onSurfaceVariant),
        ]),
      ),
    );
  }
}

/// A pill segmented control (2-4 choices): SegmentedTabs(options: {'all': 'الكل', ...}, selected:, onSelected:).
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({super.key, required this.options, required this.selected, required this.onSelected});
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(children: [
        for (final e in options.entries)
          Expanded(
            child: GestureDetector(
              onTap: () => onSelected(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected == e.key ? cs.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  boxShadow: selected == e.key ? [BoxShadow(color: cs.shadow.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))] : null,
                ),
                child: Text(e.value, textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: selected == e.key ? FontWeight.w800 : FontWeight.w600, color: selected == e.key ? cs.primary : cs.onSurfaceVariant)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// The bar fixed at the bottom of a product / cart / checkout screen: total on one side, the main button on the
/// other. Use as AppPage(bottom: CheckoutBar(...)).
class CheckoutBar extends StatelessWidget {
  const CheckoutBar({super.key, required this.label, required this.onPressed, this.total, this.totalLabel = 'الإجمالي', this.busy = false, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final Object? total;
  final String totalLabel;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: dark ? cs.surfaceContainer : cs.surface,
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(children: [
          if (total != null) ...[
            Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(totalLabel, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
              PriceTag(total, large: true),
            ]),
            Gap.w16,
          ],
          Expanded(child: AppButton(label, onPressed: onPressed, busy: busy, icon: icon, expand: true)),
        ]),
      ),
    );
  }
}

/// A soft note box: tips, payment instructions, warnings (tone: Tone.info / warning / success / danger).
class InfoBanner extends StatelessWidget {
  const InfoBanner(this.text, {super.key, this.title, this.tone = Tone.info, this.icon});
  final String text;
  final String? title;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = switch (tone) {
      Tone.success => const Color(0xFF16A34A),
      Tone.warning => const Color(0xFFD97706),
      Tone.danger => cs.error,
      _ => cs.primary,
    };
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: c.withValues(alpha: 0.25))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon ?? Icons.info_outline_rounded, color: c),
        Gap.w12,
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) Text(title!, style: TextStyle(fontWeight: FontWeight.w800, color: c)),
            Text(text, style: const TextStyle(height: 1.5)),
          ]),
        ),
      ]),
    );
  }
}

/// Fades and slides its child in (index: stagger list items: Appear(index: i, child: ...)).
class Appear extends StatelessWidget {
  const Appear({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + 40 * index.clamp(0, 8)),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child)),
      child: child,
    );
  }
}

// ------------------------------------------------------------------ navigation

/// One tab of the bottom navigation.
class NavTab {
  const NavTab({required this.label, required this.icon, required this.page, this.selectedIcon, this.badge});
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final Widget page;

  /// e.g. Backend.unread: shows a count on the tab.
  final ValueListenable<int>? badge;
}

/// The app's bottom navigation (3-5 tabs); each tab keeps its state.
class AppNavShell extends StatefulWidget {
  const AppNavShell({super.key, required this.tabs});
  final List<NavTab> tabs;

  @override
  State<AppNavShell> createState() => _AppNavShellState();
}

class _AppNavShellState extends State<AppNavShell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    Widget icon(NavTab t, IconData i) {
      final b = t.badge;
      if (b == null) return Icon(i);
      return ValueListenableBuilder<int>(
        valueListenable: b,
        builder: (context, n, _) => Badge(isLabelVisible: n > 0, label: Text(n > 99 ? '99+' : '$n'), child: Icon(i)),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(index: _i, children: [for (final t in widget.tabs) t.page]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          destinations: [
            for (final t in widget.tabs)
              NavigationDestination(icon: icon(t, t.icon), selectedIcon: icon(t, t.selectedIcon ?? t.icon), label: t.label),
          ],
        ),
      ),
    );
  }
}
