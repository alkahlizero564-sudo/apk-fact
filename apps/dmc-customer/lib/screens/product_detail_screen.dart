import 'package:material_ui/material_ui.dart';
import '../backend.dart';
import '../ui_kit.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final double exchangeRate;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.exchangeRate,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _qty = 1;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final double usdPrice = (p['price_usd'] as num?)?.toDouble() ?? 0.0;
    final double priceSdg = usdPrice * widget.exchangeRate;
    final int stock = (p['stock_quantity'] as num?)?.toInt() ?? 0;
    final bool isSoldOut = stock <= 0 || (p['is_active'] == false);

    return AppPage(
      title: 'تفاصيل المنتج',
      subtitle: p['name'] ?? '',
      back: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartScreen()),
          ),
        ),
      ],
      bottom: CheckoutBar(
        label: isSoldOut ? 'المنتج غير متوفر' : 'إضافة إلى السلة',
        total: priceSdg * _qty,
        onPressed: isSoldOut
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  final existing = await Backend.list(
                    T.cartItems,
                    filters: {
                      'customer_id': 'eq.${Backend.userId}',
                      'product_id': 'eq.${p['id']}',
                    },
                  );

                  if (existing.isNotEmpty) {
                    final currentQty = (existing.first['quantity'] as num?)?.toInt() ?? 0;
                    await Backend.update(T.cartItems, existing.first['id'], {
                      'quantity': currentQty + _qty,
                    });
                  } else {
                    await Backend.insert(T.cartItems, {
                      'customer_id': Backend.userId,
                      'product_id': p['id'],
                      'quantity': _qty,
                    });
                  }
                  Backend.toast('تمت إضافة $_qty من "${p['name']}" إلى السلة');
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  Backend.toast('حدث خطأ أثناء إضافة المنتج للسلة');
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        busy: _busy,
      ),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          AppCard(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.md),
              child: AppImage(
                p['image_url'] ?? '',
                height: 250,
                width: double.infinity,
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  p['name'] ?? '',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: Gap.sm),
              StatusBadge(
                isSoldOut ? 'نفذت الكمية' : 'متوفر بالمخزن',
                tone: isSoldOut ? Tone.danger : Tone.success,
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          AppCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('السعر بالجنيه السوداني:', style: TextStyle(fontWeight: FontWeight.w600)),
                    PriceTag(priceSdg, large: true),
                  ],
                ),
                const Divider(height: Gap.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('السعر بالدولار الأمريكي:', style: TextStyle(color: Colors.grey)),
                    Text(
                      '\$${usdPrice.toStringAsFixed(2)} USD',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('سعر الصرف المعتمد:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    Text(
                      '1 USD = ${money(widget.exchangeRate)}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.md),
          const SectionHeader('تفاصيل ومواصفات المنتج'),
          const SizedBox(height: Gap.xs),
          AppCard(
            child: Text(
              (p['description'] != null && (p['description'] as String).trim().isNotEmpty)
                  ? p['description']
                  : 'معدات ومستلزمات طبية وكيميائية معتمدة وعالية الجودة من شركة ديالا للمعدات الطبية.',
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ),
          const SizedBox(height: Gap.lg),
          if (!isSoldOut) ...[
            const SectionHeader('تحديد الكمية المطلوبة'),
            const SizedBox(height: Gap.xs),
            AppCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (stock > 0)
                        Text(
                          'المتوفر بالمخزن: $stock قطعة',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                  QuantityStepper(
                    value: _qty,
                    onChanged: (v) {
                      if (v >= 1 && (stock <= 0 || v <= stock)) {
                        setState(() => _qty = v);
                      } else if (v > stock) {
                        Backend.toast('الكمية المطلوبة تتجاوز المخزون ($stock)');
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}
