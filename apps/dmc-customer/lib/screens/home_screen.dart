import 'package:material_ui/material_ui.dart';
import '../backend.dart';
import '../ui_kit.dart';
import '../ui.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return LiveQuery<List<Map<String, dynamic>>>(
      load: () => Backend.list(T.settings),
      builder: (context, settingsRows) {
        final double exchangeRate = settingsRows.isNotEmpty
            ? (settingsRows.first['usd_exchange_rate'] as num?)?.toDouble() ?? 2750.0
            : 2750.0;

        return LiveQuery<List<Map<String, dynamic>>>(
          load: () => Backend.list(
            T.products,
            filters: {'is_active': 'eq.true'},
            order: 'created_at.desc',
          ),
          builder: (context, products) {
            final filtered = products.where((p) {
              final name = (p['name'] ?? '').toString().toLowerCase();
              return name.contains(_searchQuery.toLowerCase());
            }).toList();

            return AppPage(
              title: 'DMC ديالا',
              subtitle: 'المعدات والمستهلكات الطبية',
              actions: [
                _CartBadge(),
              ],
              body: ListView(
                padding: const EdgeInsets.all(Gap.md),
                children: [
                  HeroHeader(
                    greeting: 'مرحباً بك في ديالا',
                    title: 'المعدات الطبية والكيميائية',
                    subtitle: 'DIALA MEDICAL & CHEMICAL EQUIPMENT',
                    avatarName: Backend.fullName,
                  ),
                  const SizedBox(height: Gap.md),
                  UsdRateBadge(rate: exchangeRate),
                  const SizedBox(height: Gap.md),
                  AppSearch(
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: Gap.lg),
                  const SectionHeader('قائمة المنتجات'),
                  const SizedBox(height: Gap.sm),
                  if (filtered.isEmpty)
                    const EmptyState(
                      title: 'لا توجد منتجات',
                      message: 'لم يتم العثور على منتجات تطابق بحثك.',
                      icon: Icons.inventory_2_outlined,
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.68,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        return Appear(
                          index: index,
                          child: DmcProductCard(
                            product: product,
                            exchangeRate: exchangeRate,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailScreen(
                                    product: product,
                                    exchangeRate: exchangeRate,
                                  ),
                                ),
                              );
                            },
                            onAddToCart: () => _addToCart(product),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: Gap.xl),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    try {
      final existing = await Backend.list(
        T.cartItems,
        filters: {
          'customer_id': 'eq.${Backend.userId}',
          'product_id': 'eq.${product['id']}',
        },
      );

      if (existing.isNotEmpty) {
        final currentQty = (existing.first['quantity'] as num?)?.toInt() ?? 1;
        await Backend.update(T.cartItems, existing.first['id'], {
          'quantity': currentQty + 1,
        });
      } else {
        await Backend.insert(T.cartItems, {
          'customer_id': Backend.userId,
          'product_id': product['id'],
          'quantity': 1,
        });
      }
      Backend.toast('تمت إضافة "${product['name']}" إلى السلة');
    } catch (e) {
      Backend.toast('تعذر إضافة المنتج');
    }
  }
}

class _CartBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LiveQuery<List<Map<String, dynamic>>>(
      load: () => Backend.list(
        T.cartItems,
        filters: {'customer_id': 'eq.${Backend.userId}'},
      ),
      builder: (context, items) {
        final count = items.length;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              ),
            ),
            if (count > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
