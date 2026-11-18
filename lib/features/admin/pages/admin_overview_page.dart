import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../models/product_model.dart';
import '../../../services/mock_data_service.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../widgets/admin_orders_logic.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/admin_ui.dart';

/// Admin dashboard: live operations KPIs, sales chart, top categories,
/// live orders and low-stock alerts — all computed from store data.
class AdminOverviewPage extends StatefulWidget {
  final List<OrderModel> orders;
  final String Function(OrderModel) customerName;
  final Future<void> Function(OrderModel) onAdvance;
  final ValueChanged<AdminSection> onOpenSection;
  final Future<void> Function(ProductModel, ProductVariant) onRestock;

  const AdminOverviewPage({
    super.key,
    required this.orders,
    required this.customerName,
    required this.onAdvance,
    required this.onOpenSection,
    required this.onRestock,
  });

  @override
  State<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<AdminOverviewPage> {
  String _range = 'today';
  String _ordersFilter = 'all';

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  int get _days => _range == 'today' ? 1 : (_range == '7d' ? 7 : 30);

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get _rangeStart => _today.subtract(Duration(days: _days - 1));

  List<OrderModel> _inRange(DateTime start, DateTime end) =>
      widget.orders.where((o) => !o.createdAt.isBefore(start) && o.createdAt.isBefore(end)).toList();

  List<OrderModel> get _rangeOrders => _inRange(_rangeStart, _today.add(const Duration(days: 1)));

  List<OrderModel> get _previousOrders => _inRange(_rangeStart.subtract(Duration(days: _days)), _rangeStart);

  double _revenue(List<OrderModel> list) =>
      list.where((o) => o.status != OrderStatus.cancelled).fold(0.0, (s, o) => s + o.grandTotal);

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final orders = widget.orders;
    final rangeOrders = _rangeOrders;
    final revenue = _revenue(rangeOrders);
    final prevRevenue = _revenue(_previousOrders);
    final delivered = rangeOrders.where((o) => o.status == OrderStatus.delivered).length;

    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Good morning' : (now.hour < 17 ? 'Good afternoon' : 'Good evening');

    return ListView(
      padding: EdgeInsets.fromLTRB(mobile ? 16 : 32, 28, mobile ? 16 : 32, 48),
      children: [
        AdminPageHeader(
          title: '$greeting, team',
          subtitle: '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]} ${now.year} · Nizampet Dark Store (500090)',
          actions: [
            AdminSegmented<String>(
              options: const [('today', 'Today'), ('7d', '7 days'), ('30d', '30 days')],
              value: _range,
              onChanged: (v) => setState(() => _range = v),
            ),
            OutlinedButton.icon(
              onPressed: () => showCsvExportDialog(context, title: 'Export orders (${_rangeLabel()})', csv: ordersCsv(rangeOrders)),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Export'),
              style: OutlinedButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: AppColors.border)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 960 ? 4 : (c.maxWidth >= 480 ? 2 : 1);
            final w = (c.maxWidth - (cols - 1) * 16) / cols;
            final kpis = [
              AdminKpiCard(
                label: 'New orders',
                value: '${orders.where((o) => o.status == OrderStatus.placed).length}',
                caption: 'Awaiting acceptance',
                icon: Icons.notifications_none_rounded,
                tint: AppColors.accentLight,
                ink: const Color(0xFF946200),
                onTap: () => widget.onOpenSection(AdminSection.orders),
              ),
              AdminKpiCard(
                label: 'Picking & packing',
                value: '${orders.where((o) => o.status == OrderStatus.confirmed || o.status == OrderStatus.packing).length}',
                caption: 'Active on floor',
                icon: Icons.inventory_2_outlined,
                tint: AppColors.infoLight,
                ink: AppColors.info,
                onTap: () => widget.onOpenSection(AdminSection.orders),
              ),
              AdminKpiCard(
                label: 'Out for delivery',
                value: '${orders.where((o) => o.status == OrderStatus.outForDelivery).length}',
                caption: 'Riders on route',
                icon: Icons.local_shipping_outlined,
                tint: AppColors.primaryLight,
                ink: AppColors.primaryDeep,
                onTap: () => widget.onOpenSection(AdminSection.orders),
              ),
              AdminKpiCard(
                label: _range == 'today' ? 'Today sales' : 'Sales · ${_rangeLabel()}',
                value: qbRupees(revenue),
                caption: '$delivered orders completed',
                icon: Icons.trending_up_rounded,
                tint: AppColors.primary,
                ink: Colors.white,
                onTap: () => widget.onOpenSection(AdminSection.reports),
              ),
            ];
            return Wrap(spacing: 16, runSpacing: 16, children: [for (final k in kpis) SizedBox(width: w, child: k)]);
          },
        ),
        const SizedBox(height: 16),
        _twoUp(
          left: _salesPanel(rangeOrders, revenue, prevRevenue),
          right: _topCategoriesPanel(rangeOrders, revenue, delivered),
        ),
        const SizedBox(height: 16),
        _twoUp(left: _liveOrdersPanel(), right: _lowStockPanel()),
      ],
    );
  }

  String _rangeLabel() => _range == 'today' ? 'today' : (_range == '7d' ? 'last 7 days' : 'last 30 days');

  Widget _twoUp({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 900) return Column(children: [left, const SizedBox(height: 16), right]);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(flex: 2, child: left), const SizedBox(width: 16), Expanded(child: right)],
        );
      },
    );
  }

  Widget _salesPanel(List<OrderModel> rangeOrders, double revenue, double prevRevenue) {
    final values = <double>[];
    final counts = <int>[];
    final labels = <String>[];
    final ticks = <String>[];

    if (_range == 'today') {
      for (var h = 7; h <= 22; h++) {
        final hourOrders = rangeOrders.where((o) => o.createdAt.hour == h && o.status != OrderStatus.cancelled).toList();
        values.add(hourOrders.fold(0.0, (s, o) => s + o.grandTotal));
        counts.add(hourOrders.length);
        final label = '${h % 12 == 0 ? 12 : h % 12} ${h >= 12 ? 'PM' : 'AM'}';
        labels.add(label);
        ticks.add((h - 7) % 3 == 0 ? label.replaceAll(' ', '') : '');
      }
    } else {
      for (var d = 0; d < _days; d++) {
        final day = _rangeStart.add(Duration(days: d));
        final dayOrders = rangeOrders
            .where((o) =>
                o.createdAt.year == day.year &&
                o.createdAt.month == day.month &&
                o.createdAt.day == day.day &&
                o.status != OrderStatus.cancelled)
            .toList();
        values.add(dayOrders.fold(0.0, (s, o) => s + o.grandTotal));
        counts.add(dayOrders.length);
        labels.add('${day.day} ${_months[day.month - 1]}');
        final every = _days <= 7 ? 1 : 5;
        ticks.add(d % every == 0 ? '${day.day}' : '');
      }
    }

    String? delta;
    var up = true;
    if (prevRevenue > 0) {
      final pct = (revenue - prevRevenue) / prevRevenue * 100;
      up = pct >= 0;
      delta = '${up ? '▲' : '▼'} ${pct.abs().toStringAsFixed(1)}% vs previous';
    }

    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_range == 'today' ? 'Sales by hour' : 'Daily sales',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(qbRupees(revenue), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        if (delta != null)
                          QbPill(
                            label: delta,
                            background: up ? AppColors.primaryLight : AppColors.errorLight,
                            foreground: up ? AppColors.primaryDeep : AppColors.error,
                            fontSize: 12,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                _range == 'today' ? 'Today · 7 AM – 10 PM' : _rangeLabel().replaceFirst('l', 'L'),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AdminBarChart(
            values: values,
            labels: labels,
            ticks: ticks,
            details: [for (var i = 0; i < values.length; i++) '${qbRupees(values[i])} · ${counts[i]} orders'],
            semanticLabel: 'Bar chart of sales for ${_rangeLabel()}',
          ),
        ],
      ),
    );
  }

  Widget _topCategoriesPanel(List<OrderModel> rangeOrders, double revenue, int delivered) {
    final byCat = <String, double>{};
    for (final o in rangeOrders.where((o) => o.status != OrderStatus.cancelled)) {
      for (final i in o.items) {
        byCat[i.product.categoryId] = (byCat[i.product.categoryId] ?? 0) + i.totalPrice;
      }
    }
    final sorted = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
    final maxVal = top.isEmpty ? 1.0 : top.first.value;
    final validOrders = rangeOrders.where((o) => o.status != OrderStatus.cancelled).length;
    final aov = validOrders == 0 ? 0 : revenue / validOrders;

    String catName(String id) {
      for (final c in MockDataService.categories) {
        if (c.id == id) return c.name;
      }
      return 'Other';
    }

    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Top categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              TextButton(onPressed: () => widget.onOpenSection(AdminSection.reports), child: const Text('View report')),
            ],
          ),
          const SizedBox(height: 6),
          if (top.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No sales in this period yet', style: TextStyle(color: AppColors.textSecondary)),
            ),
          for (final e in top) ...[
            Row(
              children: [
                Expanded(child: Text(catName(e.key), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                Text(qbRupees(e.value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 6),
            AdminMeter(fraction: e.value / maxVal),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(12)),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Avg order value ${qbRupees(aov)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: ' · $delivered delivered orders · ${rangeOrders.length} placed'),
              ]),
              style: const TextStyle(fontSize: 12, color: Color(0xFF4A3F12), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveOrdersPanel() {
    final allOrders = List<OrderModel>.from(widget.orders)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final live = allOrders.where((o) => OrderFlow.isActive(o.status)).toList();
    final cancelled = allOrders.where((o) => o.status == OrderStatus.cancelled).toList();

    List<OrderModel> displayed;
    switch (_ordersFilter) {
      case 'live':
        displayed = live;
        break;
      case 'cancelled':
        displayed = cancelled;
        break;
      case 'all':
      default:
        displayed = allOrders;
        break;
    }
    final rows = displayed.take(10).toList();
    final newCount = live.where((o) => o.status == OrderStatus.placed).length;
    final cancelledCount = cancelled.length;

    return AdminPanel(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Live orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    if (newCount > 0) QbPill(label: '$newCount new', background: AppColors.primary, foreground: Colors.white),
                    if (cancelledCount > 0) ...[
                      const SizedBox(width: 6),
                      QbPill(
                        label: '$cancelledCount cancelled',
                        background: AppColors.errorLight,
                        foreground: AppColors.error,
                      ),
                    ],
                  ],
                ),
                AdminSegmented<String>(
                  options: const [
                    ('all', 'All'),
                    ('live', 'Live'),
                    ('cancelled', 'Cancelled'),
                  ],
                  value: _ordersFilter,
                  onChanged: (v) => setState(() => _ordersFilter = v),
                ),
                TextButton(onPressed: () => widget.onOpenSection(AdminSection.orders), child: const Text('Open order board')),
              ],
            ),
          ),
          AdminTable(
            columns: const ['Order', 'Customer', 'Items', 'Amount', 'Status', 'Placed', ''],
            flex: const [1.1, 1.3, 0.6, 0.8, 1.4, 0.8, 1.1],
            minWidth: 720,
            empty: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _ordersFilter == 'cancelled'
                    ? 'No cancelled orders'
                    : (_ordersFilter == 'live' ? 'No live orders right now' : 'No orders yet'),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            rows: rows.map((o) {
              final isCancelled = o.status == OrderStatus.cancelled;
              final isDelivered = o.status == OrderStatus.delivered;
              final st = OrderStatusStyle.of(o.status);

              String statusLabel = st.label;
              Color bg = st.background;
              Color fg = st.foreground;
              if (isCancelled) {
                statusLabel = o.cancellationReason == 'Cancelled by store'
                    ? 'Cancelled (Store)'
                    : 'Cancelled (Customer)';
                bg = AppColors.errorLight;
                fg = AppColors.error;
              }

              return <Widget>[
                Text(o.orderNumber, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(widget.customerName(o), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                Text('${o.items.fold<int>(0, (s, i) => s + i.quantity)}', style: const TextStyle(fontSize: 13)),
                Text(qbRupees(o.grandTotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: QbPill(label: statusLabel, background: bg, foreground: fg, dot: true, fontSize: 12),
                ),
                Text(qbAge(o.createdAt) == 'now' ? 'just now' : '${qbAge(o.createdAt)} ago',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                Align(
                  alignment: Alignment.centerRight,
                  child: isCancelled
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Restocked',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.error),
                          ),
                        )
                      : isDelivered
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Completed',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryDeep),
                              ),
                            )
                          : OutlinedButton(
                              onPressed: () => widget.onAdvance(o),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: AppColors.primaryTint,
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: Color(0xFFCFE3D6)),
                                minimumSize: const Size(0, 34),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                              child: Text(OrderFlow.shortAction(o.status)),
                            ),
                ),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _lowStockPanel() {
    final low = <(ProductModel, ProductVariant)>[];
    for (final p in MockDataService.products) {
      for (final v in p.variants) {
        if (v.stockQuantity < 15) low.add((p, v));
      }
    }
    low.sort((a, b) => a.$2.stockQuantity.compareTo(b.$2.stockQuantity));

    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Low stock alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              TextButton(onPressed: () => widget.onOpenSection(AdminSection.inventory), child: const Text('Inventory')),
            ],
          ),
          if (low.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('All products are well stocked', style: TextStyle(color: AppColors.textSecondary)),
            ),
          for (final item in low.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 40, height: 40, child: QbProductImage(product: item.$1, radius: 10, iconSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item.$1.name} ${item.$2.unit}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        Text(
                          item.$2.stockQuantity == 0 ? 'Out of stock' : '${item.$2.stockQuantity} left',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: item.$2.stockQuantity <= 5 ? AppColors.error : const Color(0xFF8A5A00),
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      await widget.onRestock(item.$1, item.$2);
                      if (mounted) setState(() {});
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      side: const BorderSide(color: AppColors.border),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Restock'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
