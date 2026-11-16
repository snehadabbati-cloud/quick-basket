import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../widgets/admin_ui.dart';

class _Customer {
  final String userId;
  final String name;
  final List<OrderModel> orders;

  _Customer(this.userId, this.name, this.orders);

  double get spend => orders.where((o) => o.status != OrderStatus.cancelled).fold(0.0, (s, o) => s + o.grandTotal);
  int get validOrders => orders.where((o) => o.status != OrderStatus.cancelled).length;
  DateTime get firstOrder => orders.map((o) => o.createdAt).reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime get lastOrder => orders.map((o) => o.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
  OrderModel get latest => orders.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);

  String get segment {
    final daysSinceLast = DateTime.now().difference(lastOrder).inDays;
    if (orders.length >= 10) return 'Loyal';
    if (daysSinceLast > 14) return 'At risk';
    if (DateTime.now().difference(firstOrder).inDays <= 7) return 'New';
    return 'Regular';
  }

  String get initials =>
      name.split(' ').where((s) => s.isNotEmpty).take(2).map((s) => s[0].toUpperCase()).join();
}

/// Customers derived from order history with a profile side panel.
class AdminCustomersPage extends StatefulWidget {
  final List<OrderModel> orders;
  final String Function(OrderModel) customerName;
  final ValueChanged<String> onViewOrders;

  const AdminCustomersPage({
    super.key,
    required this.orders,
    required this.customerName,
    required this.onViewOrders,
  });

  @override
  State<AdminCustomersPage> createState() => _AdminCustomersPageState();
}

class _AdminCustomersPageState extends State<AdminCustomersPage> {
  String _query = '';
  String? _selectedId;

  static const _segmentColors = {
    'Loyal': (AppColors.primaryLight, AppColors.primaryDeep),
    'New': (AppColors.infoLight, Color(0xFF34479A)),
    'Regular': (AppColors.surfaceMuted, AppColors.textBody),
    'At risk': (AppColors.accentLight, AppColors.accentInk),
  };

  List<_Customer> get _customers {
    final byUser = <String, List<OrderModel>>{};
    for (final o in widget.orders) {
      byUser.putIfAbsent(o.userId, () => []).add(o);
    }
    final list = byUser.entries.map((e) => _Customer(e.key, widget.customerName(e.value.first), e.value)).toList()
      ..sort((a, b) => b.lastOrder.compareTo(a.lastOrder));
    final q = _query.toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.userId.toLowerCase().contains(q) ||
            (c.latest.address?.formattedAddress.toLowerCase().contains(q) ?? false))
        .toList();
  }

  String _shortDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final days = DateTime.now().difference(DateTime(d.year, d.month, d.day)).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final customers = _customers;
    final selected = customers.where((c) => c.userId == _selectedId).firstOrNull ?? customers.firstOrNull;
    final wide = Responsive.width(context) >= 1200;

    final table = AdminPanel(
      padding: EdgeInsets.zero,
      clip: true,
      child: AdminTable(
        columns: const ['Customer', 'Area', 'Orders', 'Lifetime spend', 'Last order', 'Segment'],
        flex: const [1.8, 1.6, 0.7, 1.1, 0.9, 0.9],
        minWidth: 760,
        rowColors: customers.map((c) => c.userId == selected?.userId ? AppColors.primaryTint : null).toList(),
        empty: const Padding(
          padding: EdgeInsets.all(28),
          child: Text('No customers yet — they appear after their first order', style: TextStyle(color: AppColors.textSecondary)),
        ),
        rows: customers.map((c) {
          final on = c.userId == selected?.userId;
          final seg = _segmentColors[c.segment]!;
          return <Widget>[
            InkWell(
              onTap: () => setState(() => _selectedId = c.userId),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: on ? AppColors.primary : AppColors.primaryLight, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(c.initials,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: on ? Colors.white : AppColors.primaryDeep)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            Text(c.latest.address?.areaStreet ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
            Text('${c.orders.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            Text(qbRupees(c.spend), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            Text(_shortDate(c.lastOrder), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            Align(
              alignment: Alignment.centerLeft,
              child: QbPill(label: c.segment, background: seg.$1, foreground: seg.$2, fontSize: 12),
            ),
          ];
        }).toList(),
      ),
    );

    final panel = selected == null ? const SizedBox.shrink() : _profile(selected);

    return ListView(
      padding: EdgeInsets.fromLTRB(mobile ? 16 : 32, 24, mobile ? 16 : 32, 40),
      children: [
        AdminPageHeader(
          title: 'Customers',
          subtitle: '${customers.length} customers who have ordered from this store',
          actions: [
            SizedBox(
              width: 320,
              height: 44,
              child: AdminSearchField(hint: 'Search by name, ID or address', filled: false, onChanged: (v) => setState(() => _query = v)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: table), const SizedBox(width: 18), SizedBox(width: 360, child: panel)],
          )
        else ...[
          table,
          const SizedBox(height: 18),
          panel,
        ],
      ],
    );
  }

  Widget _profile(_Customer c) {
    final aov = c.validOrders == 0 ? 0 : c.spend / c.validOrders;
    final recent = c.orders.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final address = c.latest.address;

    Widget stat(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.adminBackground, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                FittedBox(child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              ],
            ),
          ),
        );

    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(c.initials, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('Customer since ${_shortDate(c.firstOrder)}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              stat('Orders', '${c.orders.length}'),
              const SizedBox(width: 10),
              stat('Spend', qbRupees(c.spend)),
              const SizedBox(width: 10),
              stat('Avg order', qbRupees(aov)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Saved address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: address == null
                ? const Text('No address on file', style: TextStyle(color: AppColors.textSecondary))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(address.type, style: const TextStyle(fontWeight: FontWeight.w800)),
                          if (address.isDefault) ...[
                            const SizedBox(width: 6),
                            const QbPill(
                              label: 'DEFAULT',
                              background: AppColors.primaryLight,
                              foreground: AppColors.primaryDeep,
                              fontSize: 10,
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(address.formattedAddress, style: const TextStyle(fontSize: 13, color: AppColors.textBody, height: 1.5)),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          const Text('Recent orders', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          for (final o in recent.take(3))
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.orderNumber, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                        Text(qbFriendlyDate(o.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Builder(builder: (context) {
                    final st = OrderStatusStyle.of(o.status);
                    return QbPill(label: st.label, background: st.background, foreground: st.foreground);
                  }),
                  const SizedBox(width: 10),
                  Text(qbRupees(o.grandTotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: c.userId));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer ID copied')));
                    }
                  },
                  child: const Text('Copy customer ID'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => widget.onViewOrders(c.name),
                  child: const Text('View all orders'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
