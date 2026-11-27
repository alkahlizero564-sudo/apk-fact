import 'package:material_ui/material_ui.dart';
import '../backend.dart';
import '../ui_kit.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'الإشعارات',
      actions: [
        AppButton('قراءة الكل', kind: ButtonKind.text, onPressed: () => Backend.markAllRead()),
      ],
      body: LiveQuery<List<Map<String, dynamic>>>(
        load: () => Backend.inbox(),
        empty: (rows) => rows.isEmpty,
        emptyText: 'لا توجد إشعارات حالياً',
        builder: (context, items) {
          return ListView.separated(
            padding: const EdgeInsets.all(Gap.md),
            itemCount: items.length,
            separatorBuilder: (_, _) => Gap.h12,
            itemBuilder: (context, index) {
              final n = items[index];
              return Appear(
                index: index,
                child: AppCard(
                  onTap: () => Backend.markRead(n['id']),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active, 
                        color: n['read_at'] == null ? Theme.of(context).colorScheme.primary : Colors.grey
                      ),
                      Gap.w12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(n['body'] ?? ''),
                            Text(dateText(n['created_at']), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
