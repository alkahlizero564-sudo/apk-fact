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

/// The whole app's theme from the design's main color (and optional font family). Use it for theme AND darkTheme:
///   theme: appTheme(seed: const Color(0xFF0F766E)), darkTheme: appTheme(seed: ..., brightness: Brightness.dark)
ThemeData appTheme({required Color seed, Brightness brightness = Brightness.light, String? fontFamily, Color? secondary}) {
  final cs = ColorScheme.fromSeed(seedColor: seed, brightness: brightness, secondary: secondary);
  final dark = brightness == Brightness.dark;
  final base = ThemeData(useMaterial3: true, colorScheme: cs, brightness: brightness, fontFamily: fontFamily);
  final field = OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide.none);
  return base.copyWith(
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
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: dark ? 0.35 : 0.55)),
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
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
        side: BorderSide(color: cs.outlineVariant),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
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
    return Padding(
      padding: margin,
      child: Card(
        color: color,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
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

/// A product / item card for grids (GridView with crossAxisCount: 2, childAspectRatio: 0.68).
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.title, this.image, this.price, this.subtitle, this.badge, this.onTap, this.onAdd, this.favorite, this.onFavorite});
  final String title;
  final String? image;
  final Object? price;
  final String? subtitle;
  final String? badge;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final bool? favorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              AppImage(image, radius: 0),
              if (badge != null)
                PositionedDirectional(top: Gap.sm, start: Gap.sm, child: StatusBadge(badge!, tone: Tone.info)),
              if (onFavorite != null)
                PositionedDirectional(
                  top: Gap.xs,
                  end: Gap.xs,
                  child: IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    onPressed: onFavorite,
                    icon: Icon(favorite == true ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 18,
                        color: favorite == true ? cs.error : null),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.sm),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.3)),
              if (subtitle != null) ...[
                Gap.h4,
                Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
              Gap.h8,
              Row(children: [
                Expanded(child: Text(money(price), style: tt.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w800))),
                if (onAdd != null)
                  IconButton.filled(visualDensity: VisualDensity.compact, onPressed: onAdd, icon: const Icon(Icons.add_rounded, size: 20)),
              ]),
            ]),
          ),
        ]),
      ),
    );
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
