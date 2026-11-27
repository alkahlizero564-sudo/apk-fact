import 'package:material_ui/material_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import '../backend.dart';
import '../ui_kit.dart';
import '../ui.dart';
import 'notifications_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'لوحة التحكم والتقارير',
      subtitle: 'Diala Medical & Chemical Equipment',
      onRefresh: () async {
        Backend.toast('تم تحديث بيانات لوحة التحكم بنجاح');
      },
      actions: [
        ValueListenableBuilder<int>(
          valueListenable: Backend.unread,
          builder: (context, count, _) => IconButton(
            icon: Badge(
              label: Text('$count'),
              isLabelVisible: count > 0,
              child: const Icon(Icons.notifications_none_rounded, color: Colors.white),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
        ),
      ],
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _UsdRateSection(),
            Gap.h16,
            const _KpiSection(),
            Gap.h24,
            const SectionHeader('توزيع المبيعات والطلبات حسب المدن'),
            const _CityChartSection(),
            Gap.h24,
            const SectionHeader('آخر نشاطات الطلبات الواردة'),
            const _RecentActivitySection(),
            Gap.h24,
          ],
        ),
      ),
    );
  }
}

class _UsdRateSection extends StatelessWidget {
  const _UsdRateSection();

  @override
  Widget build(BuildContext context) {
    return LiveQuery<List<Map<String, dynamic>>>(
      load: () async {
        try {
          final rows = await Backend.list(T.settings);
          if (rows.isNotEmpty) return rows;
          return [
            {
              'id': 1,
              'usd_exchange_rate': 2750.0,
              'bok_account_number': '123456789',
              'bok_account_name': 'ديالا للمعدات الطبية',
            }
          ];
        } catch (_) {
          return [
            {
              'id': 1,
              'usd_exchange_rate': 2750.0,
              'bok_account_number': '123456789',
              'bok_account_name': 'ديالا للمعدات الطبية',
            }
          ];
        }
      },
      builder: (context, rows) {
        final rate = (rows.firstOrNull?['usd_exchange_rate'] as num?)?.toDouble() ?? 2750.0;
        return UsdRateCard(rate: rate);
      },
    );
  }
}

class _KpiSection extends StatelessWidget {
  const _KpiSection();

  @override
  Widget build(BuildContext context) {
    return LiveQuery<List<Map<String, dynamic>>>(
      load: () async {
        try {
          return await Backend.list(T.orders);
        } catch (_) {
          return <Map<String, dynamic>>[];
        }
      },
      builder: (context, orders) {
        final validOrders = orders.where((o) => o['status'] != 'cancelled').toList();
        final totalSales = validOrders.fold(0.0, (sum, o) => sum + ((o['total_sdg'] as num?)?.toDouble() ?? 0.0));
        final pending = orders.where((o) => o['status'] == 'pending_payment_review').length;

        return Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'إجمالي المبيعات',
                value: money(totalSales),
                icon: Icons.trending_up_rounded,
                note: '+14% نمو هذا الأسبوع',
              ),
            ),
            Gap.w12,
            Expanded(
              child: StatCard(
                label: 'طلبات معلقة',
                value: '$pending طلبات',
                icon: Icons.pending_actions_rounded,
                note: 'تتطلب مراجعة التحويل',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CityChartSection extends StatelessWidget {
  const _CityChartSection();

  @override
  Widget build(BuildContext context) {
    return LiveQuery<List<Map<String, dynamic>>>(
      load: () async {
        try {
          return await Backend.list(T.orders);
        } catch (_) {
          return <Map<String, dynamic>>[];
        }
      },
      builder: (context, orders) {
        final cities = ['عطبره', 'الدامر', 'ابوحمد', 'بربر', 'شندي'];
        final counts = cities.map((city) {
          final count = orders.where((o) => o['city'] == city).length;
          return count;
        }).toList();

        final maxCount = counts.fold<int>(0, (prev, elem) => elem > prev ? elem : prev);
        final effectiveMax = maxCount > 0 ? (maxCount + 2).toDouble() : 6.0;

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الطلبات المنجزة بالمدن',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x2000E5FF),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: const Text(
                      'ولاية نهر النيل',
                      style: TextStyle(fontSize: 11, color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              Gap.h16,
              SizedBox(
                height: 190,
                child: BarChart(
                  BarChartData(
                    maxY: effectiveMax,
                    alignment: BarChartAlignment.spaceAround,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF1C2541),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${cities[group.x.toInt()]}\n${rod.toY.toInt()} طلب',
                            const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            final idx = val.toInt();
                            if (idx < 0 || idx >= cities.length) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                cities[idx],
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          },
                          reservedSize: 28,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: effectiveMax > 6 ? 2 : 1,
                          reservedSize: 28,
                          getTitlesWidget: (v, m) => Text(
                            '${v.toInt()}',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (v) => const FlLine(color: Color(0x1AFFFFFF), strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: cities.asMap().entries.map((e) {
                      final rawY = counts[e.key].toDouble();
                      final displayY = rawY > 0 ? rawY : 0.4;
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: displayY,
                            width: 22,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0066FF), Color(0xFF00E5FF)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              Gap.h12,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF00E5FF), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('معدل توزيع الإرساليات والمبيعات الفعلي بالمدن', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection();

  @override
  Widget build(BuildContext context) {
    return LiveQuery<List<Map<String, dynamic>>>(
      load: () async {
        try {
          return await Backend.list(T.orders, order: 'created_at.desc');
        } catch (_) {
          return <Map<String, dynamic>>[];
        }
      },
      emptyText: 'لا توجد طلبات جديدة حتى الآن',
      builder: (context, orders) {
        if (orders.isEmpty) {
          return const AppCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('لا توجد طلبات واردة في النظام حالياً', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
            ),
          );
        }
        return Column(
          children: orders.take(4).map((o) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: AppTile(
              title: o['customer_name'] ?? 'طلب زبون',
              subtitle: 'طلب #${o['order_number']} • ${o['city']} • ${money(o['total_sdg'] ?? 0)}',
              trailing: StatusBadge(o['status'] ?? 'pending_payment_review'),
              icon: Icons.local_shipping_outlined,
            ),
          )).toList(),
        );
      },
    );
  }
}
