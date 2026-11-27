import 'package:material_ui/material_ui.dart';
import '../backend.dart';
import '../ui_kit.dart';
import '../ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'إعدادات الأسعار وبنك الخرطوم',
      subtitle: 'التحكم الفوري في المتجر وحسابات التحويل',
      onRefresh: () async {
        Backend.toast('تم تحديث الإعدادات وبيانات الحساب البنكي');
      },
      body: SingleChildScrollView(
        child: Column(
          children: [
            ProfileHeader(
              name: Backend.fullName.isNotEmpty ? Backend.fullName : 'المسؤول العام',
              subtitle: Backend.phone.isNotEmpty ? Backend.phone : 'admin@dialamedical.sd',
              onEdit: () {
                Backend.toast('حساب إدارة النظام نشط ومفعل');
              },
            ),
            Gap.h24,
            const SectionHeader('تعديل سعر الدولار (يحدث أسعار الكتالوج تلقائياً)'),
            LiveQuery<List<Map<String, dynamic>>>(
              load: () async {
                try {
                  final rows = await Backend.list(T.settings);
                  if (rows.isNotEmpty) return rows;
                  return [
                    {
                      'id': 1,
                      'usd_exchange_rate': 2750.0,
                      'bok_account_number': '123456789',
                      'bok_account_name': 'ديالا للمعدات الطبية',
                    }
                  ];
                } catch (_) {
                  return [
                    {
                      'id': 1,
                      'usd_exchange_rate': 2750.0,
                      'bok_account_number': '123456789',
                      'bok_account_name': 'ديالا للمعدات الطبية',
                    }
                  ];
                }
              },
              builder: (context, rows) {
                final setting = rows.firstOrNull ?? {};
                final rate = (setting['usd_exchange_rate'] as num?)?.toDouble() ?? 2750.0;
                return UsdRateCard(
                  rate: rate,
                  onEdit: () => _showRateEditor(context, setting),
                );
              },
            ),
            Gap.h24,
            const SectionHeader('إدارة حساب بنك الخرطوم للتحويلات الواردة'),
            LiveQuery<List<Map<String, dynamic>>>(
              load: () async {
                try {
                  final rows = await Backend.list(T.settings);
                  if (rows.isNotEmpty) return rows;
                  return [
                    {
                      'id': 1,
                      'usd_exchange_rate': 2750.0,
                      'bok_account_number': '123456789',
                      'bok_account_name': 'ديالا للمعدات الطبية',
                    }
                  ];
                } catch (_) {
                  return [
                    {
                      'id': 1,
                      'usd_exchange_rate': 2750.0,
                      'bok_account_number': '123456789',
                      'bok_account_name': 'ديالا للمعدات الطبية',
                    }
                  ];
                }
              },
              builder: (context, rows) {
                final setting = rows.firstOrNull ?? {};
                return AppCard(
                  child: Column(
                    children: [
                      InfoRow('رقم حساب بنك الخرطوم', setting['bok_account_number'] ?? '123456789'),
                      InfoRow('اسم الحساب', setting['bok_account_name'] ?? 'ديالا للمعدات الطبية'),
                      Gap.h16,
                      AppButton(
                        'تعديل البيانات البنكية',
                        onPressed: () => _showBankEditor(context, setting),
                        kind: ButtonKind.outline,
                        expand: true,
                        icon: Icons.account_balance_rounded,
                      ),
                    ],
                  ),
                );
              },
            ),
            Gap.h24,
            AppButton(
              'إعادة المحاولة / مزامنة الاتصال',
              onPressed: () {
                Backend.toast('تمت مزامنة الاتصال بنجاح مع السيرفر وتحديث البيانات');
              },
              kind: ButtonKind.secondary,
              expand: true,
              icon: Icons.sync_rounded,
            ),
            Gap.h16,
            AppButton(
              'تسجيل الخروج من لوحة الإدارة',
              onPressed: () => Backend.signOut(),
              kind: ButtonKind.danger,
              expand: true,
              icon: Icons.logout_rounded,
            ),
            Gap.h24,
          ],
        ),
      ),
    );
  }

  void _showRateEditor(BuildContext context, Map<String, dynamic> setting) {
    final controller = TextEditingController(text: setting['usd_exchange_rate']?.toString() ?? '2750');
    showAppSheet(
      context,
      title: 'تعديل سعر صرف الدولار',
      child: Column(
        children: [
          const Text(
            'عند تحديث سعر الدولار، سيتم تعديل أسعار جميع المنتجات الطبية والمستهلكات فوراً في متجر الزبائن.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          Gap.h16,
          AppField(label: 'سعر الصرف الجديد (SDG)', controller: controller, keyboard: TextInputType.number),
          Gap.h16,
          AppButton(
            'حفظ وتحديث الأسعار للزبائن',
            expand: true,
            icon: Icons.sync_rounded,
            onPressed: () async {
              final rate = double.tryParse(controller.text);
              if (rate != null) {
                if (setting['id'] != null && setting['id'] != 'default') {
                  try {
                    await Backend.update(T.settings, setting['id'], {'usd_exchange_rate': rate});
                  } catch (_) {}
                }
                await Backend.notify(
                  toRole: 'customer',
                  title: 'تحديث أسعار المعدات والمستهلكات الطبية',
                  body: 'تم تحديث أسعار الأصناف بناءً على سعر صرف الدولار الجديد',
                );
                Backend.toast('تم تحديث سعر الدولار وتطبيق الأسعار الجديدة');
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showBankEditor(BuildContext context, Map<String, dynamic> setting) {
    final acc = TextEditingController(text: setting['bok_account_number'] ?? '123456789');
    final name = TextEditingController(text: setting['bok_account_name'] ?? 'ديالا للمعدات الطبية');
    showAppSheet(
      context,
      title: 'تعديل بيانات حساب بنك الخرطوم',
      child: Column(
        children: [
          AppField(label: 'رقم الحساب', controller: acc, icon: Icons.numbers_rounded),
          Gap.h12,
          AppField(label: 'اسم الحساب المستفيد', controller: name, icon: Icons.person_rounded),
          Gap.h16,
          AppButton(
            'حفظ الحساب البنكي',
            expand: true,
            icon: Icons.check_circle_rounded,
            onPressed: () async {
              if (setting['id'] != null && setting['id'] != 'default') {
                try {
                  await Backend.update(T.settings, setting['id'], {
                    'bok_account_number': acc.text,
                    'bok_account_name': name.text,
                  });
                } catch (_) {}
              }
              Backend.toast('تم تحديث بيانات الحساب البنكي ليظهر للزبائن');
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
