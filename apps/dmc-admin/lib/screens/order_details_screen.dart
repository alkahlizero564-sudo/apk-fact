import 'package:material_ui/material_ui.dart';
import '../backend.dart';
import '../ui_kit.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late Map<String, dynamic> _order;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _isBusy = true);
    try {
      final updated = await Backend.update(T.orders, _order['id'], {'status': status});
      if (updated != null) {
        setState(() => _order = updated);
      }
      if (_order['customer_id'] != null) {
        await Backend.notify(
          toUser: _order['customer_id'],
          title: 'تحديث حالة الطلب',
          body: 'طلبك رقم #${_order['order_number']} أصبح الآن: ${_statusArabic(status)}',
        );
      }
      Backend.toast('تم تحديث حالة الطلب إلى ${_statusArabic(status)}');
    } catch (e) {
      Backend.toast('فشل التحديث: $e');
    } finally {
      setState(() => _isBusy = false);
    }
  }

  String _statusArabic(String status) {
    switch (status) {
      case 'pending_payment_review': return 'بانتظار مراجعة الدفع';
      case 'payment_confirmed': return 'تم تأكيد الدفع';
      case 'processing': return 'قيد التجهيز المخبري';
      case 'ready_for_pickup': return 'جاهز للاستلام';
      case 'out_for_delivery': return 'خرج للتوصيل';
      case 'delivered': return 'تم التسليم بنجاح';
      case 'cancelled': return 'ملغي';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _order['status'] as String? ?? 'pending_payment_review';
    final isBank = _order['payment_method'] == 'bank_of_khartoum';

    return AppPage(
      title: 'تفاصيل الطلب #${_order['order_number']}',
      back: true,
      body: SingleChildScrollView(
        child: Column(
          children: [
            AppCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('حالة الطلب الحالية', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      StatusBadge(status),
                    ],
                  ),
                  Gap.h16,
                  OrderTimeline(
                    current: _getStatusIndex(status),
                    steps: const [
                      TrackStep('بانتظار الدفع'),
                      TrackStep('تم التأكيد'),
                      TrackStep('قيد التجهيز'),
                      TrackStep('جاهز/للتوصيل'),
                      TrackStep('تم التسليم'),
                    ],
                  ),
                ],
              ),
            ),
            Gap.h16,
            const SectionHeader('بيانات الزبون والتسليم'),
            AppCard(
              child: Column(
                children: [
                  InfoRow('اسم الزبون', _order['customer_name'] ?? '---'),
                  InfoRow('رقم الهاتف السوداني', _order['customer_phone'] ?? '---'),
                  InfoRow('المدينة', _order['city'] ?? 'عطبره'),
                  InfoRow('طريقة الاستلام', _order['delivery_method'] == 'delivery' ? 'توصيل للعنوان' : 'استلام من المحل'),
                  if (_order['delivery_address'] != null)
                    InfoRow('عنوان التوصيل', _order['delivery_address']),
                ],
              ),
            ),
            Gap.h16,
            if (isBank) ...[
              const SectionHeader('إثبات الدفع (بنك الخرطوم)'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoRow('اسم صاحب الحساب المحول منه', _order['transfer_sender_name'] ?? 'غير متوفر', strong: true),
                    Gap.h12,
                    if (_order['transfer_receipt_url'] != null && _order['transfer_receipt_url'].toString().isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AppImage(_order['transfer_receipt_url'], height: 200, width: double.infinity),
                      )
                    else
                      Container(
                        height: 90,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0x1AFFFFFF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x20FFFFFF)),
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_rounded, color: Color(0xFF00E5FF)),
                              SizedBox(width: 8),
                              Text('إشعار التحويل البنكي الإلكتروني مرفق بالطلب', style: TextStyle(color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                      ),
                    Gap.h16,
                    AppButton(
                      _order['is_name_matched'] == true ? '✓ الاسم متطابق مع اسم الزبون (إلغاء)' : 'مطابقة اسم المحول مع الزبون',
                      onPressed: () async {
                        final v = await Backend.update(T.orders, _order['id'], {
                          'is_name_matched': !(_order['is_name_matched'] == true),
                        });
                        if (v != null) setState(() => _order = v);
                        Backend.toast('تم تحديث حالة مطابقة الاسم');
                      },
                      kind: _order['is_name_matched'] == true ? ButtonKind.secondary : ButtonKind.outline,
                      expand: true,
                    ),
                  ],
                ),
              ),
              Gap.h16,
            ],
            const SectionHeader('الأصناف المطلوبة'),
            LiveQuery<List<Map<String, dynamic>>>(
              load: () => Backend.list(T.orderItems, filters: {'order_id': 'eq.${_order['id']}'}),
              emptyText: 'تفاصيل الصنف: ${money(_order['total_sdg'] ?? 0)}',
              builder: (context, items) {
                if (items.isEmpty) {
                  return AppCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('إجمالي الطلب المحسوب:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text(money(_order['total_sdg'] ?? 0), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF00E5FF))),
                      ],
                    ),
                  );
                }
                return Column(
                  children: items.map((item) => AppTile(
                    title: item['product_name'] ?? 'مستلزمات طبية',
                    subtitle: 'الكمية: ${item['quantity']} • السعر بالدولار: \$${item['price_usd'] ?? 0}',
                    trailing: Text(money(item['subtotal_sdg'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
                  )).toList(),
                );
              },
            ),
            Gap.h24,
            if (status != 'delivered' && status != 'cancelled')
              AppButton(
                'تحديث حالة الطلب للخطوة التالية',
                onPressed: () => _showStatusPicker(),
                expand: true,
                busy: _isBusy,
                icon: Icons.edit_note_rounded,
              ),
            Gap.h24,
          ],
        ),
      ),
    );
  }

  int _getStatusIndex(String status) {
    switch (status) {
      case 'pending_payment_review': return 0;
      case 'payment_confirmed': return 1;
      case 'processing': return 2;
      case 'ready_for_pickup':
      case 'out_for_delivery': return 3;
      case 'delivered': return 4;
      default: return 0;
    }
  }

  void _showStatusPicker() {
    showAppSheet(
      context,
      title: 'تغيير حالة الطلب',
      child: Column(
        children: [
          _statusTile('تأكيد الدفع البنكي', 'payment_confirmed'),
          _statusTile('قيد التجهيز المخبري', 'processing'),
          _statusTile('جاهز للاستلام من المحل', 'ready_for_pickup'),
          _statusTile('خرج للتوصيل بالمدينة', 'out_for_delivery'),
          _statusTile('تم التسليم للزبون', 'delivered'),
          const Divider(color: Color(0x1AFFFFFF)),
          _statusTile('إلغاء الطلب', 'cancelled', danger: true),
        ],
      ),
    );
  }

  Widget _statusTile(String label, String status, {bool danger = false}) {
    return AppTile(
      title: label,
      icon: danger ? Icons.cancel_outlined : Icons.check_circle_outline,
      onTap: () {
        Navigator.pop(context);
        _updateStatus(status);
      },
    );
  }
}
