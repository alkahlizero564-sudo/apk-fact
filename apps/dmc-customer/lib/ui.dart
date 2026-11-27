import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'backend.dart';
import 'ui_kit.dart';

/// Specialized DMC product card showing both USD and SDG prices
class DmcProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final double exchangeRate;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const DmcProductCard({
    super.key,
    required this.product,
    required this.exchangeRate,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final double usdPrice = (product['price_usd'] as num?)?.toDouble() ?? 0.0;
    final double sdgPrice = usdPrice * exchangeRate;
    final int stock = (product['stock_quantity'] as num?)?.toInt() ?? 0;
    final bool isOut = stock <= 0 || (product['is_active'] == false);

    return ProductCard(
      title: product['name'] ?? '',
      subtitle: '\$${usdPrice.toStringAsFixed(2)} USD',
      image: product['image_url'] ?? '',
      price: sdgPrice,
      badge: isOut ? 'نفذت الكمية' : (stock < 10 ? 'متبقي $stock' : null),
      soldOut: isOut,
      onTap: onTap,
      onAdd: isOut ? null : onAddToCart,
    );
  }
}

/// Specialized DMC Order summary card for customer lists
class DmcOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const DmcOrderCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final orderNum = order['order_number'] ?? 'DMC-${order['id'].toString().substring(0, 6)}';
    final totalSdg = (order['total_sdg'] as num?)?.toDouble() ?? 0.0;
    final city = order['city'] ?? 'غير محدد';
    final deliveryMethod = order['delivery_method'] == 'delivery' ? 'توصيل إلى $city' : 'استلام من المحل';
    final createdAt = order['created_at'] != null ? dateText(order['created_at']) : '';

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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              DmcOrderStatusBadge(status: order['status'] ?? 'pending_payment_review'),
            ],
          ),
          const SizedBox(height: Gap.sm),
          InfoRow('طريقة الاستلام:', deliveryMethod),
          InfoRow('إجمالي المبلغ:', money(totalSdg), strong: true),
          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: Gap.xs),
            Text(
              createdAt,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Status badge custom-mapped for DMC order lifecycle
class DmcOrderStatusBadge extends StatelessWidget {
  final String status;

  const DmcOrderStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    String text;
    Tone tone;

    switch (status) {
      case 'pending_payment_review':
        text = 'بانتظار مراجعة الدفع';
        tone = Tone.warning;
        break;
      case 'payment_confirmed':
        text = 'تم تأكيد الدفع';
        tone = Tone.success;
        break;
      case 'processing':
        text = 'قيد التجهيز';
        tone = Tone.info;
        break;
      case 'ready_for_pickup':
        text = 'جاهز للاستلام';
        tone = Tone.info;
        break;
      case 'out_for_delivery':
        text = 'في الطريق إليك';
        tone = Tone.warning;
        break;
      case 'delivered':
        text = 'تم التسليم';
        tone = Tone.success;
        break;
      case 'cancelled':
        text = 'ملغي';
        tone = Tone.danger;
        break;
      default:
        text = status;
        tone = Tone.neutral;
    }

    return StatusBadge(text, tone: tone);
  }
}

/// Displays active USD to SDG exchange rate banner
class UsdRateBadge extends StatelessWidget {
  final double rate;

  const UsdRateBadge({super.key, required this.rate});

  @override
  Widget build(BuildContext context) {
    return InfoBanner(
      '1 دولار أمريكي = ${money(rate)}',
      title: 'سعر الصرف المعتمد',
      tone: Tone.info,
    );
  }
}

/// Helper for selecting bank transfer receipt image
Future<String?> pickAndUploadReceipt(ImageSource source) async {
  final ImagePicker picker = ImagePicker();
  final XFile? file = await picker.pickImage(
    source: source,
    imageQuality: 80,
    maxWidth: 1000,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return await Backend.uploadFile(bytes, extension: 'jpg');
}
