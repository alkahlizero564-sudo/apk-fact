import 'package:material_ui/material_ui.dart';
import '../backend.dart';
import '../ui_kit.dart';
import '../ui.dart';
import 'order_details_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _filter = 'all';
  String _search = '';

  String _filterName(String key) {
    switch (key) {
      case 'all': return 'الكل';
      case 'pending_payment_review': return 'بانتظار الدفع';
      case 'processing': return 'قيد التجهيز';
      case 'delivered': return 'مكتملة';
      default: return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'طلبات الزبائن',
      subtitle: 'إدارة عمليات الدفع والتوصيل',
      onRefresh: () async {
        Backend.toast('تم تحديث قائمة الطلبات');
        setState(() {});
      },
      body: Column(
        children: [
          AppSearch(onChanged: (v) => setState(() => _search = v)),
          Gap.h12,
          ChoiceRow(
            options: const {
              'all': 'الكل',
              'pending_payment_review': 'بانتظار الدفع',
              'processing': 'قيد التجهيز',
              'delivered': 'مكتملة',
            },
            selected: _filter,
            onSelected: (v) {
              setState(() => _filter = v);
              Backend.toast('تصفية الطلبات: ${_filterName(v)}');
            },
          ),
          Gap.h16,
          Expanded(
            child: LiveQuery<List<Map<String, dynamic>>>(
              load: () async {
                try {
                  return await Backend.list(T.orders, order: 'created_at.desc');
                } catch (_) {
                  return <Map<String, dynamic>>[];
                }
              },
              builder: (context, orders) {
                final filtered = orders.where((o) {
                  final matchesFilter = _filter == 'all' || o['status'] == _filter;
                  final matchesSearch = _search.isEmpty ||
                      (o['customer_name'] ?? '').toString().contains(_search) ||
                      (o['order_number'] ?? '').toString().contains(_search) ||
                      (o['city'] ?? '').toString().contains(_search);
                  return matchesFilter && matchesSearch;
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    title: 'لا توجد طلبات في هذا القسم',
                    message: _filter == 'all'
                        ? 'لم يتم تقديم أي طلبات من الزبائن حتى الآن.'
                        : 'لا توجد طلبات مطابقة لتصنيف "${_filterName(_filter)}".',
                    icon: Icons.receipt_long_rounded,
                    action: 'إعادة المحاولة / تحديث',
                    onAction: () {
                      Backend.toast('تم إعادة فحص الطلبات وتحديث الحالة');
                      setState(() {});
                    },
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => Gap.h12,
                  itemBuilder: (context, index) {
                    final order = filtered[index];
                    return Appear(
                      index: index,
                      child: AdminOrderCard(
                        order: order,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)),
                        ),
                        onConfirmPayment: () => _updateStatus(order, 'payment_confirmed'),
                        onReject: () => _updateStatus(order, 'cancelled'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(Map<String, dynamic> order, String status) async {
    try {
      await Backend.update(T.orders, order['id'], {'status': status});
      if (order['customer_id'] != null) {
        await Backend.notify(
          toUser: order['customer_id'],
          title: status == 'payment_confirmed' ? 'تم تأكيد طلبك ومطابقة الدفع' : 'تم إلغاء الطلب',
          body: 'طلبك رقم #${order['order_number']} أصبح الآن: ${status == 'payment_confirmed' ? 'مؤكد وجاري التجهيز' : 'ملغي'}',
        );
      }
      Backend.toast(status == 'payment_confirmed' ? 'تم تأكيد الطلب بنجاح' : 'تم رفض الطلب');
      setState(() {});
    } catch (e) {
      Backend.toast('حدث خطأ: $e');
    }
  }
}
