import 'package:material_ui/material_ui.dart';
import '../backend.dart';
import '../ui_kit.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'إشعارات وتنبيهات الإدارة',
      back: true,
      actions: [
        AppButton(
          'قراءة الكل',
          onPressed: () {
            Backend.markAllRead();
            Backend.toast('تم تحديد جميع الإشعارات كمقروءة');
          },
          kind: ButtonKind.text,
        ),
      ],
      body: LiveQuery<List<Map<String, dynamic>>>(
        load: () async {
          try {
            return await Backend.inbox();
          } catch (_) {
            return <Map<String, dynamic>>[];
          }
        },
        emptyText: 'لا توجد تنبيهات جديدة',
        builder: (context, items) {
          if (items.isEmpty) {
            return EmptyState(
              title: 'لا توجد تنبيهات حالياً',
              message: 'ستظهر هنا إشعارات الطلبات الجديدة ومطابقة الدفع من الزبائن فور وصولها.',
              icon: Icons.notifications_none_rounded,
              action: 'تحديث التنبيهات',
              onAction: () => Backend.toast('تم فحص الإشعارات الجديدة'),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(color: Color(0x1AFFFFFF)),
            itemBuilder: (context, index) {
              final item = items[index];
              return AppTile(
                title: item['title'] ?? 'تنبيه إداري',
                subtitle: item['body'] ?? '',
                icon: Icons.notifications_active_rounded,
                onTap: () {
                  Backend.markRead(item['id']);
                  Backend.toast('تم فتح الإشعار');
                },
                trailing: item['read_at'] == null
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Color(0xFF00E5FF), shape: BoxShape.circle),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
