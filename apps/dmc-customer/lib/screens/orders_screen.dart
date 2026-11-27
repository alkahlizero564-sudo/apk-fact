import 'package:material_ui/material_ui.dart';
import '../backend.dart';
import '../ui_kit.dart';
import '../ui.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'طلباتي',
      subtitle: 'متابعة حالة طلباتك الحالية والسابقة',
      body: LiveQuery<List<Map<String, dynamic>>>(
        load: () => Backend.list(
          T.orders,
          filters: {'customer_id': 'eq.${Backend.userId}'},
          order: 'created_at.desc',
        ),
        empty: (rows) => rows.isEmpty,
        emptyText: 'لا توجد طلبات بعد',
        builder: (context, orders) {
          return ListView.separated(
            padding: const EdgeInsets.all(Gap.md),
            itemCount: orders.length,
            separatorBuilder: (_, _) => Gap.h12,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Appear(
                index: index,
                child: DmcOrderCard(
                  order: order,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
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
