// In-app updates (added by APK Fact at build time; not part of the app's own code).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const int apkfactVersion = __APKFACT_VERSION__;
const String apkfactManifest = '__APKFACT_MANIFEST__';

void apkfactRunApp(Widget app) => runApp(ApkFactUpdateGate(child: app));

class ApkFactUpdateGate extends StatefulWidget {
  const ApkFactUpdateGate({super.key, required this.child});
  final Widget child;

  @override
  State<ApkFactUpdateGate> createState() => _ApkFactUpdateGateState();
}

class _ApkFactUpdateGateState extends State<ApkFactUpdateGate> with WidgetsBindingObserver {
  Map<String, dynamic>? _update;
  DateTime? _later;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_update != null) return;
    final later = _later;
    if (later != null && DateTime.now().difference(later).inMinutes < 30) return;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final uri = Uri.parse('$apkfactManifest?t=${DateTime.now().millisecondsSinceEpoch}');
      final res = await (await client.getUrl(uri)).close();
      if (res.statusCode != 200) return;
      final data = jsonDecode(await res.transform(utf8.decoder).join());
      if (data is Map && data['version'] is int && (data['version'] as int) > apkfactVersion && data['apk'] is String) {
        if (mounted) setState(() => _update = Map<String, dynamic>.from(data));
      }
    } catch (_) {
      // Offline or no manifest yet: try again next time.
    } finally {
      client.close();
    }
  }

  Future<void> _install() async {
    final u = _update;
    if (u == null) return;
    setState(() => _opening = true);
    try {
      await launchUrl(Uri.parse(u['apk'] as String), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final u = _update;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          if (u != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 28,
              // Above MaterialApp there is no MediaQuery yet; buttons need one.
              child: MediaQuery.fromView(
                view: View.of(context),
                child: Material(
                color: const Color(0xFF111827),
                elevation: 12,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.system_update, color: Color(0xFFA78BFA), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تحديث جديد متوفر (${u['versionName'] ?? u['version']})',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (u['notes'] as String?)?.isNotEmpty == true
                                  ? u['notes'] as String
                                  : 'اضغط تحديث لتنزيل النسخة الجديدة وتثبيتها.',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _update = null;
                          _later = DateTime.now();
                        }),
                        child: const Text('لاحقاً', style: TextStyle(color: Color(0xFFCBD5E1))),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6E4BFF)),
                        onPressed: _opening ? null : _install,
                        child: Text(_opening ? '…' : 'تحديث'),
                      ),
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
}
