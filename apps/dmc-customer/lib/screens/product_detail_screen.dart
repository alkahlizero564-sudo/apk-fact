import 'package:material_ui/material_ui.dart';
import '../backend.dart';
import '../ui_kit.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final double exchangeRate;

  const ProductDetailScreen({super.key, required this.product, required this.exchangeRate});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _qty = 1;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final priceSdg = ((p['price_usd'] as num?)?.toDouble() ?? 0.0) * widget.exchangeRate;

    return AppPage(
      title: 'تفاصيل المنتج',
      back: true,
      bottom: CheckoutBar(
        label: 'إضافة للسلة',
        total: priceSdg * _qty,
        onPressed: () async {
          setState(() => _busy = true);
          try {
            await Backend.insert(T.cartItems, {
              'customer_id': Backend.userId,
              'product_id': p['id'],
              'quantity': _qty,
            });
            Backend.toast('تمت الإضافة للسلة');
            if (mounted) Navigator.pop(context);
          } catch (e) {
            Backend.toast('حدث خطأ');
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
              child: AppImage(p['image_url'] ?? '', height: 250, width: double.infinity),
            ),
          ),
          const SizedBox(height: Gap.lg),
          Text(p['name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: Gap.sm),
          PriceTag(priceSdg, large: true),
          const SizedBox(height: Gap.md),
          Text(p['description'] ?? 'لا يوجد وصف متاح لهذا المنتج حالياً.', style: const TextStyle(fontSize: 16, height: 1.5)),
          const SizedBox(height: Gap.lg),
          const SectionHeader('الكمية المطلوبة'),
          QuantityStepper(value: _qty, onChanged: (v) => setState(() => _qty = v)),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
