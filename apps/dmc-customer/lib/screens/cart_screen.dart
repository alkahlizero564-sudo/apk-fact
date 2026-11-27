import 'package:material_ui/material_ui.dart';
import '../backend.dart';
import '../ui_kit.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'سلة المشتريات',
      subtitle: 'تأكد من الكميات قبل إتمام الطلب',
      body: LiveQuery<List<Map<String, dynamic>>>(
        load: () async {
          final cartItems = await Backend.list(
            T.cartItems,
            filters: {'customer_id': 'eq.${Backend.userId}'},
          );
          if (cartItems.isEmpty) return [];

          final settings = await Backend.list(T.settings);
          final rate = settings.isNotEmpty ? (settings.first['usd_exchange_rate'] as num).toDouble() : 2750.0;

          final productIds = cartItems.map((e) => e['product_id']).toList();
          final products = await Backend.list(T.products, filters: {'id': 'in.(${productIds.join(',')})'});
          final productMap = {for (var p in products) p['id']: p};

          return cartItems.map((item) {
            final p = productMap[item['product_id']];
            return {
              ...item,
              'product': p,
              'rate': rate,
            };
          }).toList();
        },
        empty: (rows) => rows.isEmpty,
        emptyText: 'سلة المشتريات فارغة',
        builder: (context, items) {
          final rate = items.first['rate'] as double;
          final totalSdg = items.fold<double>(0, (sum, item) {
            final p = item['product'] as Map<String, dynamic>?;
            final qty = (item['quantity'] as num).toInt();
            final priceUsd = (p?['price_usd'] as num?)?.toDouble() ?? 0.0;
            return sum + (priceUsd * rate * qty);
          });

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(Gap.md),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final p = item['product'] as Map<String, dynamic>?;
                    final qty = (item['quantity'] as num).toInt();
                    final priceSdg = ((p?['price_usd'] as num?)?.toDouble() ?? 0.0) * rate;

                    return Appear(
                      index: index,
                      child: AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(Radii.md),
                              child: AppImage(p?['image_url'] ?? '', width: 70, height: 70),
                            ),
                            Gap.w12,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p?['name'] ?? 'منتج', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(money(priceSdg), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                QuantityStepper(
                                  value: qty,
                                  onChanged: (v) async {
                                    if (v > 0) {
                                      await Backend.update(T.cartItems, item['id'], {'quantity': v});
                                    } else {
                                      await Backend.delete(T.cartItems, item['id']);
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () => Backend.delete(T.cartItems, item['id']),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              CheckoutBar(
                label: 'إتمام الطلب',
                total: totalSdg,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CheckoutScreen(
                        cartItems: items,
                        totalSdg: totalSdg,
                        appliedRate: rate,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
