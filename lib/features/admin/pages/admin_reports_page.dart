import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../services/mock_data_service.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../widgets/admin_ui.dart';

/// Reports: period KPIs vs previous period, daily revenue, payment mix,
/// CSV exports and top-selling products.
class AdminReportsPage extends StatefulWidget {
  final List<OrderModel> orders;

  const AdminReportsPage({super.key, required this.orders});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  String _range = '14d';
  DateTimeRange? _custom;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  (DateTime, DateTime) get _period {
    if (_range == 'custom' && _custom != null) {
      final s = _custom!.start;
      final e = _custom!.end;
      return (DateTime(s.year, s.month, s.day), DateTime(e.year, e.month, e.day).add(const Duration(days: 1)));
    }
    final days = _range == '7d' ? 7 : (_range == '30d' ? 30 : 14);
    return (_today.subtract(Duration(days: days - 1)), _today.add(const Duration(days: 1)));
  }

  int get _days => _period.$2.difference(_period.$1).inDays;

  List<OrderModel> _between(DateTime a, DateTime b) =>
      widget.orders.where((o) => !o.createdAt.isBefore(a) && o.createdAt.isBefore(b)).toList();

  String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  Future<void> _pickCustom() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _custom ?? DateTimeRange(start: _today.subtract(const Duration(days: 6)), end: _today),
    );
    if (picked != null) {
      setState(() {
        _custom = picked;
        _range = 'custom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final (start, end) = _period;
    final current = _between(start, end);
    final previous = _between(start.subtract(Duration(days: _days)), start);

    final stats = _Stats(current);
    final prev = _Stats(previous);

    String delta(double now, double before, {bool pts = false, bool inverse = false}) {
      if (before == 0) return 'No data for previous period';
      final diff = pts ? now - before : (now - before) / before * 100;
      final up = diff >= 0;
      return '${up ? '▲' : '▼'} ${diff.abs().toStringAsFixed(1)}${pts ? ' pts' : '%'} vs previous';
    }

    Color deltaColor(double now, double before, {bool inverse = false}) {
      if (before == 0) return AppColors.textSecondary;
      final good = inverse ? now <= before : now >= before;
      return good ? AppColors.primaryDeep : AppColors.error;
    }

    final kpis = [
      ('Revenue', qbRupees(stats.revenue), delta(stats.revenue, prev.revenue), deltaColor(stats.revenue, prev.revenue)),
      ('Orders delivered', '${stats.delivered}', delta(stats.delivered.toDouble(), prev.delivered.toDouble()),
          deltaColor(stats.delivered.toDouble(), prev.delivered.toDouble())),
      ('Avg order value', qbRupees(stats.aov), delta(stats.aov, prev.aov), deltaColor(stats.aov, prev.aov)),
      ('Avg items / order', stats.itemsPerOrder.toStringAsFixed(1), delta(stats.itemsPerOrder, prev.itemsPerOrder),
          deltaColor(stats.itemsPerOrder, prev.itemsPerOrder)),
      ('Cancellation rate', '${stats.cancelRate.toStringAsFixed(1)}%', delta(stats.cancelRate, prev.cancelRate, pts: true),
          deltaColor(stats.cancelRate, prev.cancelRate, inverse: true)),
    ];

    // Daily series
    final values = <double>[];
    final counts = <int>[];
    final labels = <String>[];
    final ticks = <String>[];
    final every = _days <= 7 ? 1 : (_days <= 14 ? 2 : 5);
    for (var d = 0; d < _days; d++) {
      final day = start.add(Duration(days: d));
      final dayOrders = current
          .where((o) => o.createdAt.year == day.year && o.createdAt.month == day.month && o.createdAt.day == day.day)
          .where((o) => o.status != OrderStatus.cancelled)
          .toList();
      values.add(dayOrders.fold(0.0, (s, o) => s + o.grandTotal));
      counts.add(dayOrders.length);
      labels.add(_fmt(day));
      ticks.add(d % every == 0 ? '${day.day}' : '');
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(mobile ? 16 : 32, 24, mobile ? 16 : 32, 40),
      children: [
        AdminPageHeader(
          title: 'Reports',
          subtitle: '${_fmt(start)} – ${_fmt(end.subtract(const Duration(days: 1)))} ${end.year} · Koramangala Dark Store',
          actions: [
            AdminSegmented<String>(
              options: const [('7d', '7 days'), ('14d', '14 days'), ('30d', '30 days'), ('custom', 'Custom')],
              value: _range,
              onChanged: (v) {
                if (v == 'custom') {
                  _pickCustom();
                } else {
                  setState(() => _range = v);
                }
              },
            ),
            ElevatedButton.icon(
              onPressed: () => showCsvExportDialog(context, title: 'Sales report', csv: ordersCsv(current)),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download report'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 1000 ? 5 : (c.maxWidth >= 600 ? 3 : (c.maxWidth >= 380 ? 2 : 1));
            final w = (c.maxWidth - (cols - 1) * 14) / cols;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: kpis
                  .map((k) => SizedBox(
                        width: w,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: qbCard(radius: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(k.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              Text(k.$2, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                              const SizedBox(height: 8),
                              Text(k.$3, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: k.$4)),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final chart = AdminPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Expanded(child: Text('Daily revenue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                      Text('Hover a day for details', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AdminBarChart(
                    values: values,
                    labels: labels,
                    ticks: ticks,
                    details: [for (var i = 0; i < values.length; i++) '${qbRupees(values[i])} · ${counts[i]} orders'],
                    semanticLabel: 'Daily revenue from ${_fmt(start)}',
                    height: 250,
                  ),
                ],
              ),
            );
            final side = _sidePanel(stats, current);
            if (c.maxWidth < 900) return Column(children: [chart, const SizedBox(height: 16), side]);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(flex: 2, child: chart), const SizedBox(width: 16), Expanded(child: side)],
            );
          },
        ),
        const SizedBox(height: 16),
        _topProducts(current, stats.revenue),
      ],
    );
  }

  Widget _sidePanel(_Stats stats, List<OrderModel> current) {
    final total = stats.upiRevenue + stats.codRevenue;
    final upiShare = total == 0 ? 0.0 : stats.upiRevenue / total;
    final codShare = total == 0 ? 0.0 : 1 - upiShare;

    Widget legend(Color color, String label, double share, double value) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
              Text('${(share * 100).round()}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              SizedBox(
                width: 84,
                child: Text(qbRupees(value),
                    textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
            ],
          ),
        );

    final itemsCsv = StringBuffer('product,unit,units_sold,revenue\n');
    for (final p in _productTotals(current)) {
      itemsCsv.writeln([p.$1, p.$2, p.$3, p.$4.toStringAsFixed(2)].map(csvCell).join(','));
    }
    final stockCsv = StringBuffer('product,unit,sku,stock,selling_price\n');
    for (final p in MockDataService.products) {
      for (final v in p.variants) {
        stockCsv.writeln([p.name, v.unit, v.sku ?? v.id, v.stockQuantity, v.sellingPrice.toStringAsFixed(2)].map(csvCell).join(','));
      }
    }

    final exports = [
      ('Sales report', 'CSV · orders, totals, payments', ordersCsv(current)),
      ('Items sold', 'CSV · units and revenue per product', itemsCsv.toString().trimRight()),
      ('Inventory snapshot', 'CSV · stock and price per variant', stockCsv.toString().trimRight()),
    ];

    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Payment mix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Semantics(
            label: 'UPI and card ${(upiShare * 100).round()} percent, cash on delivery ${(codShare * 100).round()} percent',
            child: SizedBox(
              height: 14,
              child: total == 0
                  ? Container(decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(4)))
                  : Row(
                      children: [
                        if (upiShare > 0)
                          Expanded(
                            flex: (upiShare * 1000).round(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.horizontal(
                                  left: const Radius.circular(4),
                                  right: Radius.circular(codShare == 0 ? 4 : 0),
                                ),
                              ),
                            ),
                          ),
                        if (upiShare > 0 && codShare > 0) const SizedBox(width: 2),
                        if (codShare > 0)
                          Expanded(
                            flex: (codShare * 1000).round(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.horizontal(
                                  right: const Radius.circular(4),
                                  left: Radius.circular(upiShare == 0 ? 4 : 0),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          legend(AppColors.primary, 'UPI / Card', upiShare, stats.upiRevenue),
          legend(AppColors.accent, 'Cash on Delivery', codShare, stats.codRevenue),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
          const Text('Export', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final e in exports)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => showCsvExportDialog(context, title: e.$1, csv: e.$3),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(9)),
                          child: const Icon(Icons.description_outlined, color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                              Text(e.$2, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.download_rounded, color: AppColors.textSecondary, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// (product name, unit, units sold, revenue) sorted by revenue.
  List<(String, String, int, double, String)> _productTotals(List<OrderModel> orders) {
    final map = <String, (String, String, int, double, String)>{};
    for (final o in orders.where((o) => o.status != OrderStatus.cancelled)) {
      for (final i in o.items) {
        final key = '${i.product.id}-${i.variant.id}';
        final prev = map[key];
        map[key] = (
          i.product.name,
          i.variant.unit,
          (prev?.$3 ?? 0) + i.quantity,
          (prev?.$4 ?? 0) + i.totalPrice,
          i.product.categoryId,
        );
      }
    }
    return map.values.toList()..sort((a, b) => b.$4.compareTo(a.$4));
  }

  Widget _topProducts(List<OrderModel> current, double revenue) {
    final top = _productTotals(current).take(8).toList();
    final maxRev = top.isEmpty ? 1.0 : top.first.$4;
    final itemRevenue = _productTotals(current).fold<double>(0, (s, p) => s + p.$4);

    String catName(String id) {
      for (final c in MockDataService.categories) {
        if (c.id == id) return c.name;
      }
      return '—';
    }

    return AdminPanel(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text('Top selling products', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          AdminTable(
            columns: const ['#', 'Product', 'Category', 'Units sold', 'Revenue', 'Share of item sales'],
            flex: const [0.3, 2.2, 1.6, 0.8, 0.9, 1.6],
            minWidth: 820,
            empty: const Padding(
              padding: EdgeInsets.all(28),
              child: Text('No sales in this period', style: TextStyle(color: AppColors.textSecondary)),
            ),
            rows: [
              for (var i = 0; i < top.length; i++)
                <Widget>[
                  Text('${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  Text('${top[i].$1} ${top[i].$2}', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  Text(catName(top[i].$5), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
                  Text('${top[i].$3}', style: const TextStyle(fontSize: 13)),
                  Text(qbRupees(top[i].$4), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  Row(
                    children: [
                      Expanded(child: AdminMeter(fraction: top[i].$4 / maxRev)),
                      const SizedBox(width: 10),
                      Text('${itemRevenue == 0 ? 0 : (top[i].$4 / itemRevenue * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 12, color: AppColors.textBody)),
                    ],
                  ),
                ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Stats {
  final List<OrderModel> orders;
  _Stats(this.orders);

  List<OrderModel> get _valid => orders.where((o) => o.status != OrderStatus.cancelled).toList();

  double get revenue => _valid.fold(0.0, (s, o) => s + o.grandTotal);
  int get delivered => orders.where((o) => o.status == OrderStatus.delivered).length;
  double get aov => _valid.isEmpty ? 0 : revenue / _valid.length;
  double get itemsPerOrder =>
      _valid.isEmpty ? 0 : _valid.fold<int>(0, (s, o) => s + o.items.fold<int>(0, (t, i) => t + i.quantity)) / _valid.length;
  double get cancelRate =>
      orders.isEmpty ? 0 : orders.where((o) => o.status == OrderStatus.cancelled).length / orders.length * 100;
  double get upiRevenue => _valid.where((o) => o.paymentMethod != 'cod').fold(0.0, (s, o) => s + o.grandTotal);
  double get codRevenue => _valid.where((o) => o.paymentMethod == 'cod').fold(0.0, (s, o) => s + o.grandTotal);
}
