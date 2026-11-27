import 'package:material_ui/material_ui.dart';
import '../backend.dart';
import '../ui_kit.dart';

class OrderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? 'pending_payment_review';
    int step = 0;
    if (status == 'payment_confirmed') step = 1;
    if (status == 'processing') step = 2;
    if (status == 'ready_for_pickup' || status == 'out_for_delivery') step = 3;
    if (status == 'delivered') step = 4;

    return AppPage(
      title: 'تفاصيل الطلب',
      back: true,
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          AppCard(
            child: Column(
              children: [
                OrderTimeline(
                  current: step,
                  cancelled: status == 'cancelled',
                  steps: const [
                    TrackStep('تم الطلب'),
                    TrackStep('تأكيد الدفع'),
                    TrackStep('التجهيز'),
                    TrackStep('في الطريق'),
                    TrackStep('تم التسليم'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.lg),
          const SectionHeader('محتويات الطلب'),
          LiveQuery<List<Map<String, dynamic>>>(
            load: () => Backend.list(T.orderItems, filters: {'order_id': 'eq.${order['id']}'}),
            builder: (context, items) {
              return Column(
                children: items.map((item) => AppTile(
                  title: item['product_name'] ?? '',
                  subtitle: 'الكمية: ${item['quantity']}',
                  trailing: Text(money(item['subtotal_sdg'])),
                )).toList(),
              );
            },
          ),
          const SizedBox(height: Gap.lg),
          const SectionHeader('ملخص الدفع والتوصيل'),
          AppCard(
            child: Column(
              children: [
                InfoRow('الإجمالي', money(order['total_sdg']), strong: true),
                InfoRow('طريقة الدفع', order['payment_method'] == 'cod' ? 'عند الاستلام' : 'بنك الخرطوم'),
                InfoRow('طريقة الاستلام', order['delivery_method'] == 'pickup' ? 'من المحل' : 'توصيل لـ ${order['city']}'),
                if (order['admin_notes'] != null) ...[
                  const Divider(),
                  InfoRow('ملاحظات الإدارة', order['admin_notes']),
                ],
              ],
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
