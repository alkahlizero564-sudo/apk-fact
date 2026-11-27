import 'package:material_ui/material_ui.dart';
import 'ui_kit.dart';

const double kCardRadiusValue = 16.0;
const BorderRadius kGlobalCardRadius = BorderRadius.all(Radius.circular(kCardRadiusValue));

/// Custom Order Card for the Admin list
class AdminOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;
  final VoidCallback? onConfirmPayment;
  final VoidCallback? onReject;

  const AdminOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.onConfirmPayment,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'pending_payment_review';
    final orderNum = order['order_number'] ?? '---';
    final customer = order['customer_name'] ?? 'زبون';
    final city = order['city'] ?? 'غير محدد';
    final total = (order['total_sdg'] as num?)?.toDouble() ?? 0.0;
    final isBank = order['payment_method'] == 'bank_of_khartoum';
    final isMatched = order['is_name_matched'] == true;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'طلب #$orderNum',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              StatusBadge(status),
            ],
          ),
          Gap.h8,
          InfoRow('الزبون', customer, strong: true),
          InfoRow('المدينة', city),
          InfoRow('طريقة الدفع', isBank ? 'بنك الخرطوم' : 'عند الاستلام'),
          const Divider(height: 24, color: Color(0x1AFFFFFF)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                money(total),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Color(0xFF00E5FF),
                ),
              ),
              if (isBank)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isMatched ? const Color(0x2010B981) : const Color(0x20F59E0B),
                    borderRadius: BorderRadius.circular(Radii.sm),
                    border: Border.all(
                      color: isMatched ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isMatched ? Icons.verified_user_rounded : Icons.pending_rounded,
                        size: 14,
                        color: isMatched ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isMatched ? 'الاسم مطابق' : 'انتظار المطابقة',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isMatched ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (status == 'pending_payment_review') ...[
            Gap.h16,
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    'تأكيد الدفع',
                    onPressed: onConfirmPayment,
                    icon: Icons.check_circle_rounded,
                    kind: ButtonKind.primary,
                  ),
                ),
                Gap.w8,
                AppButton(
                  'رفض',
                  onPressed: onReject,
                  icon: Icons.close_rounded,
                  kind: ButtonKind.danger,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Ledger Transaction Tile
class LedgerTile extends StatelessWidget {
  final Map<String, dynamic> record;
  final VoidCallback onTap;

  const LedgerTile({super.key, required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSale = record['record_type'] == 'sale';
    final amount = (record['amount_sdg'] as num?)?.toDouble() ?? 0.0;
    final title = record['title'] ?? 'بدون عنوان';
    final date = record['record_date'] ?? '';
    final isAi = record['is_ai_parsed'] == true;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isSale ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (isSale ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              isSale ? Icons.add_chart_rounded : Icons.shopping_cart_checkout_rounded,
              color: isSale ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Gap.h4,
                Text(
                  '${record['city'] ?? ''} • ${dateText(date)}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isSale ? "+" : "-"}${money(amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: isSale ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
              ),
              if (isAi)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0x2000E5FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'مسح ذكي AI',
                    style: TextStyle(fontSize: 10, color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// USD Rate Display Card
class UsdRateCard extends StatelessWidget {
  final double rate;
  final VoidCallback? onEdit;

  const UsdRateCard({super.key, required this.rate, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0066FF), Color(0xFF00E5FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.currency_exchange_rounded, color: Colors.white),
          ),
          Gap.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'سعر صرف الدولار (USD/SDG)',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                ),
                Gap.h4,
                Text(
                  '1 \$ = ${money(rate).replaceAll(' ج.س', '')} ج.س',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            AppButton('تعديل', onPressed: onEdit, kind: ButtonKind.outline),
        ],
      ),
    );
  }
}
