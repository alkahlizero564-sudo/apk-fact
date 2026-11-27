import 'package:material_ui/material_ui.dart';
import '../backend.dart';
import '../ui_kit.dart';
import 'product_form_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'إدارة وتعديل المنتجات',
      subtitle: 'تحديث تلقائي لأسعار المستهلكات والمعدات',
      onRefresh: () async {
        Backend.toast('تم تحديث قائمة المنتجات والأسعار');
        setState(() {});
      },
      floating: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0066FF),
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormScreen())),
        label: const Text('إضافة منتج'),
        icon: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          AppSearch(onChanged: (v) => setState(() => _search = v)),
          Gap.h16,
          Expanded(
            child: LiveQuery<List<Map<String, dynamic>>>(
              load: () async {
                try {
                  return await Backend.list(T.products, order: 'created_at.desc');
                } catch (e) {
                  if (e.toString().contains('400')) {
                    Backend.toast('خطأ 400 في مزامنة المنتجات: يرجى التحقق من الاتصال');
                  }
                  return <Map<String, dynamic>>[];
                }
              },
              builder: (context, products) {
                final filtered = products.where((p) =>
                    (p['name'] ?? '').toString().toLowerCase().contains(_search.toLowerCase()) ||
                    (p['description'] ?? '').toString().toLowerCase().contains(_search.toLowerCase())).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    title: 'لا توجد منتجات مسجلة',
                    message: _search.isEmpty
                        ? 'لم يتم إضافة منتجات طبية في الكتالوج حتى الآن.'
                        : 'لم يتم العثور على منتجات مطابقة للبحث "$_search".',
                    icon: Icons.inventory_2_outlined,
                    action: 'إضافة أول منتج',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => Gap.h12,
                  itemBuilder: (context, index) {
                    final p = filtered.isNotEmpty && index < filtered.length ? filtered[index] : <String, dynamic>{};
                    final priceUsd = (p['price_usd'] as num?)?.toDouble() ?? 0.0;
                    final priceSdg = priceUsd * 2750.0;
                    final isActive = p['is_active'] != false;
                    final imageUrl = p['image_url']?.toString() ?? '';

                    return AppCard(
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: imageUrl.isNotEmpty
                                ? AppImage(imageUrl, width: 64, height: 64)
                                : Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0066FF).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.medical_services_rounded, color: Color(0xFF00E5FF), size: 30),
                                  ),
                          ),
                          Gap.w12,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['name'] ?? 'منتج طبي',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Gap.h4,
                                Text(
                                  '\$${priceUsd.toStringAsFixed(2)}  •  ${money(priceSdg)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF00E5FF)),
                                ),
                                Gap.h4,
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0x1AFFFFFF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'مخزون: ${p['stock_quantity'] ?? 100}',
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('تحديث تلقائي بالسعر', style: TextStyle(fontSize: 10, color: Color(0xFF10B981))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF00E5FF), size: 26),
                                tooltip: 'تعديل المنتج',
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ProductFormScreen(product: p)),
                                ),
                              ),
                              Switch(
                                value: isActive,
                                activeThumbColor: const Color(0xFF00E5FF),
                                onChanged: (val) async {
                                  try {
                                    await Backend.update(T.products, p['id'], {'is_active': val});
                                    Backend.toast(val ? 'تم تنشيط المنتج في متجر الزبائن' : 'تم إيقاف ظهور المنتج للزبائن');
                                    setState(() {});
                                  } catch (e) {
                                    if (e.toString().contains('400')) {
                                      Backend.toast('خطأ 400: فشل تحديث حالة المنتج');
                                    } else {
                                      Backend.toast('خطأ: $e');
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
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
}
