import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../services/supabase_service.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../controllers/rider_session.dart';
import '../widgets/rider_helpers.dart';
import '../widgets/rider_ui.dart';
import 'delivery_flow_screens.dart';
import 'rider_login_screen.dart';

enum _HistoryRange { today, yesterday, week, month, all }

String _assignedLabel(DateTime t) {
  final age = qbAge(t);
  return age == 'now' ? 'Assigned just now' : 'Assigned $age ago';
}

/// 4. Orders: Active / Completed (history with date filters) / Cancelled.
class RiderOrdersTab extends StatefulWidget {
  const RiderOrdersTab({super.key});

  @override
  State<RiderOrdersTab> createState() => _RiderOrdersTabState();
}

class _RiderOrdersTabState extends State<RiderOrdersTab> {
  _HistoryRange _range = _HistoryRange.all;

  bool _inRange(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_range) {
      _HistoryRange.today => !t.isBefore(today),
      _HistoryRange.yesterday => !t.isBefore(today.subtract(const Duration(days: 1))) && t.isBefore(today),
      _HistoryRange.week => !t.isBefore(today.subtract(Duration(days: now.weekday - 1))),
      _HistoryRange.month => t.year == now.year && t.month == now.month,
      _HistoryRange.all => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final session = RiderSession();
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final active = session.activeDeliveries;
        final completed = session.completedDeliveries.where((o) => _inRange(o.deliveredAt ?? o.createdAt)).toList();
        final cancelled = session.cancelledDeliveries;
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('My deliveries'),
              bottom: TabBar(
                labelColor: AppColors.primaryDeep,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                tabs: [
                  Tab(text: 'Active (${active.length})'),
                  const Tab(text: 'Completed'),
                  const Tab(text: 'Cancelled'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _list(context, active, empty: 'No active deliveries.\nGo online to receive requests.', active: true),
                _list(
                  context,
                  completed,
                  empty: 'No completed deliveries in this period.',
                  header: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        for (final (r, label) in const [
                          (_HistoryRange.all, 'All'),
                          (_HistoryRange.today, 'Today'),
                          (_HistoryRange.yesterday, 'Yesterday'),
                          (_HistoryRange.week, 'This week'),
                          (_HistoryRange.month, 'This month'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () => setState(() => _range = r),
                              child: QbPill(
                                label: label,
                                background: _range == r ? AppColors.primaryDark : Colors.white,
                                foreground: _range == r ? Colors.white : AppColors.textBody,
                                fontSize: 12.5,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                _list(context, cancelled, empty: 'No cancelled deliveries.'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _list(BuildContext context, List<OrderModel> items, {required String empty, bool active = false, Widget? header}) {
    return ListView(
      padding: const EdgeInsets.all(kRiderGutter),
      children: [
        ?header,
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Center(child: Text(empty, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, height: 1.4))),
          ),
        ...items.map((o) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RDeliveryTile(
                o,
                timeLabel: active
                    ? _assignedLabel(o.assignedAt ?? o.createdAt)
                    : qbFriendlyDate(o.deliveredAt ?? o.cancelledAt ?? o.createdAt),
                onTap: () => active
                    ? openDeliveryStage(context, o)
                    : Navigator.of(context).push(riderRoute(RiderOrderHistoryDetailScreen(orderId: o.id))),
              ),
            )),
      ],
    );
  }
}

/// 4.5 Individual Order Details (history) — real timeline + earnings.
class RiderOrderHistoryDetailScreen extends StatelessWidget {
  final String orderId;
  const RiderOrderHistoryDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final session = RiderSession();
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final d = session.orderById(orderId);
        if (d == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Order not found')));
        }
        final cancelled = d.status == OrderStatus.cancelled;
        final earned = RiderSession.earningFor(d);
        final steps = <(String, DateTime?, bool)>[
          ('Order placed', d.createdAt, false),
          if (d.assignedAt != null) ('Assigned to you', d.assignedAt, false),
          if (d.pickedUpAt != null) ('Picked up from store', d.pickedUpAt, false),
          if (d.status == OrderStatus.delivered) ('Delivered · OTP verified', d.deliveredAt, false),
          if (cancelled) ('Cancelled${d.cancellationReason != null ? ' · ${d.cancellationReason}' : ''}', d.cancelledAt, true),
        ];

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: Text(d.orderNumber)),
          body: ListView(
            padding: const EdgeInsets.all(kRiderGutter),
            children: [
              RCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RStatusPill(d),
                          const SizedBox(height: 8),
                          Text(qbFriendlyDate(d.deliveredAt ?? d.cancelledAt ?? d.createdAt), style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(
                            [
                              if (RiderFormat.dropKm(d) != null) RiderFormat.km(RiderFormat.dropKm(d)),
                              if (d.items.isNotEmpty) '${d.items.fold<int>(0, (s, i) => s + i.quantity)} items',
                              d.isCod ? 'COD' : 'Prepaid',
                            ].join(' · '),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Earned', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                        Text(qbRupees(earned),
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: earned > 0 ? AppColors.primaryDeep : AppColors.textMuted)),
                        if (earned > 0 && d.tipAmount > 0)
                          Text('incl. ${qbRupees(d.tipAmount)} tip', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              const RSectionTitle('Timeline'),
              RCard(
                child: Column(
                  children: List.generate(steps.length, (i) {
                    final last = i == steps.length - 1;
                    final (label, time, bad) = steps[i];
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(color: bad ? AppColors.error : AppColors.primary, shape: BoxShape.circle),
                              ),
                              if (!last) Expanded(child: Container(width: 2, color: AppColors.border)),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: last ? 0 : 16),
                              child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: bad ? AppColors.error : AppColors.textPrimary, height: 1.1)),
                            ),
                          ),
                          if (time != null) Text(qbTime(time), style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.1)),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              FutureBuilder<String?>(
                future: SupabaseService().getReportedIssue(d.id),
                builder: (context, snap) {
                  if (snap.data == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: RCard(
                      color: AppColors.errorLight,
                      borderColor: AppColors.errorBorder,
                      child: Text(snap.data!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ),
                  );
                },
              ),
              const RSectionTitle('Delivery address'),
              RCard(child: RInfoRow(icon: Icons.home_outlined, label: d.address?.type ?? 'Address', value: RiderFormat.fullAddress(d))),
              const SizedBox(height: 12),
              ROutlineButton(
                label: 'View items & bill',
                icon: Icons.receipt_long_outlined,
                onPressed: () => Navigator.of(context).push(riderRoute(RiderOrderDetailsScreen(orderId: d.id))),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => RiderIntents.callStore(context),
                child: const Text('Problem with this order? Call store support', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      },
    );
  }
}
