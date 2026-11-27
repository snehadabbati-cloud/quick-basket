import 'package:flutter/material.dart';
import '../../../core/config/delivery_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../controllers/rider_session.dart';
import '../widgets/rider_ui.dart';
import 'orders_screens.dart';
import 'rider_login_screen.dart';

/// 5. Earnings: Daily / Weekly / Monthly with breakdown (from completed deliveries).
class RiderEarningsTab extends StatefulWidget {
  const RiderEarningsTab({super.key});

  @override
  State<RiderEarningsTab> createState() => _RiderEarningsTabState();
}

class _RiderEarningsTabState extends State<RiderEarningsTab> {
  RiderPeriod _period = RiderPeriod.week;

  @override
  Widget build(BuildContext context) {
    final session = RiderSession();
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final e = session.earnings(_period);
        final recent = session.completedDeliveries.take(4).toList();
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('Earnings')),
          body: ListView(
            padding: const EdgeInsets.all(kRiderGutter),
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    for (final (p, label) in const [(RiderPeriod.day, 'Daily'), (RiderPeriod.week, 'Weekly'), (RiderPeriod.month, 'Monthly')])
                      Expanded(
                        child: GestureDetector(
                          key: ValueKey('period_${p.name}'),
                          onTap: () => setState(() => _period = p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _period == p ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: _period == p ? [const BoxShadow(color: Color(0x14000000), blurRadius: 6)] : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(label,
                                style: TextStyle(fontWeight: FontWeight.w800, color: _period == p ? AppColors.primaryDeep : AppColors.textSecondary)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              RCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(qbRupees(e.total),
                        key: const ValueKey('earnings_total'),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
                    Text('${e.count} ${e.count == 1 ? 'delivery' : 'deliveries'}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                    const SizedBox(height: 18),
                    _BarChart(buckets: e.buckets, highlight: e.highlightIndex),
                  ],
                ),
              ),
              const RSectionTitle('Breakdown'),
              RCard(
                child: Column(
                  children: [
                    _row(Icons.delivery_dining_outlined, 'Delivery pay', '${e.count} × ${qbRupees(DeliveryConfig.defaultPerDeliveryEarning)}', qbRupees(e.deliveryPay)),
                    const Divider(height: 18),
                    _row(Icons.volunteer_activism_outlined, 'Customer tips', '100% goes to you', qbRupees(e.tips)),
                    const Divider(height: 18),
                    _row(Icons.account_balance_wallet_outlined, 'Total earnings', '', qbRupees(e.total), bold: true),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RCard(
                      onTap: () => Navigator.of(context).push(riderRoute(const RiderCashCollectedScreen())),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('COD collected today', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(qbRupees(session.codCashToday), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.accentInk)),
                          const Text('Hand over at store', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Avg per delivery', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(e.count == 0 ? '—' : qbRupees(e.total / e.count),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primaryDeep)),
                          Text(_period == RiderPeriod.day ? 'Today' : (_period == RiderPeriod.week ? 'This week' : 'This month'),
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              RSectionTitle(
                'Recent transactions',
                action: recent.isEmpty ? null : 'See all',
                onAction: () => Navigator.of(context).push(riderRoute(const RiderTransactionsScreen())),
              ),
              if (recent.isEmpty)
                const RCard(child: Text('Complete a delivery to see your earnings here.', style: TextStyle(color: AppColors.textSecondary)))
              else
                RCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(children: recent.map((o) => _TxnRow(o)).toList()),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(IconData icon, String title, String sub, String value, {bool bold = false}) => Row(
        children: [
          Icon(icon, color: bold ? AppColors.primaryDeep : AppColors.textBody, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700)),
                if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: bold ? 16 : 14, color: bold ? AppColors.primaryDeep : AppColors.textPrimary)),
        ],
      );
}

class _BarChart extends StatelessWidget {
  final List<EarningsBucket> buckets;
  final int highlight;
  const _BarChart({required this.buckets, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final maxV = buckets.fold<double>(0, (m, b) => b.amount > m ? b.amount : m);
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(buckets.length, (i) {
          final b = buckets[i];
          final sel = i == highlight;
          final h = maxV == 0 ? 0.0 : (b.amount / maxV) * 104;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FittedBox(
                    child: Text(
                      b.amount == 0 ? ' ' : '₹${b.amount.round()}',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: sel ? AppColors.primaryDeep : AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: h < 4 ? 4 : h,
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(b.label, style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w900 : FontWeight.w600, color: AppColors.textSecondary)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  final OrderModel o;
  final double? amountOverride;
  final String? subtitleOverride;
  const _TxnRow(this.o, {this.amountOverride, this.subtitleOverride});

  @override
  Widget build(BuildContext context) {
    final amount = amountOverride ?? RiderSession.earningFor(o);
    final when = qbFriendlyDate(o.deliveredAt ?? o.createdAt);
    return InkWell(
      onTap: () => Navigator.of(context).push(riderRoute(RiderOrderHistoryDetailScreen(orderId: o.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.south_west_rounded, size: 18, color: AppColors.primaryDeep),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delivery · ${o.orderNumber}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  Text(subtitleOverride ?? (o.tipAmount > 0 ? '$when · incl. ${qbRupees(o.tipAmount)} tip' : when),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                ],
              ),
            ),
            Text('+${qbRupees(amount)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryDeep)),
          ],
        ),
      ),
    );
  }
}

/// 5.4 Earnings Transactions (one credit per completed delivery).
class RiderTransactionsScreen extends StatelessWidget {
  const RiderTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = RiderSession();
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final all = session.completedDeliveries;
        final now = DateTime.now();
        final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        final thisWeek = all.where((o) => !(o.deliveredAt ?? o.createdAt).isBefore(weekStart)).toList();
        final earlier = all.where((o) => (o.deliveredAt ?? o.createdAt).isBefore(weekStart)).toList();
        Widget group(String title, List<OrderModel> list) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1)),
                const SizedBox(height: 8),
                RCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(children: list.map((o) => _TxnRow(o)).toList()),
                ),
                const SizedBox(height: 18),
              ],
            );
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('Transactions')),
          body: all.isEmpty
              ? const Center(child: Text('No transactions yet.', style: TextStyle(color: AppColors.textSecondary)))
              : ListView(
                  padding: const EdgeInsets.all(kRiderGutter),
                  children: [
                    if (thisWeek.isNotEmpty) group('THIS WEEK', thisWeek),
                    if (earlier.isNotEmpty) group('EARLIER', earlier),
                  ],
                ),
        );
      },
    );
  }
}

/// Extra (business need): COD cash collected today, to hand over at the store.
class RiderCashCollectedScreen extends StatelessWidget {
  const RiderCashCollectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = RiderSession();
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final list = session.codCollectedToday;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('COD cash collected')),
          body: ListView(
            padding: const EdgeInsets.all(kRiderGutter),
            children: [
              RCard(
                color: AppColors.accentLight,
                borderColor: AppColors.accentBorder,
                child: Column(
                  children: [
                    const Text('CASH COLLECTED TODAY',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.accentInk, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    Text(qbRupees(session.codCashToday), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.accentInk)),
                    Text('${list.length} cash-on-delivery ${list.length == 1 ? 'order' : 'orders'}',
                        style: const TextStyle(fontSize: 12, color: AppColors.accentInk)),
                  ],
                ),
              ),
              const RSectionTitle('Orders'),
              if (list.isEmpty)
                const RCard(child: Text('No cash-on-delivery orders today.', style: TextStyle(color: AppColors.textSecondary)))
              else
                RCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(
                    children: list
                        .map((o) => _TxnRow(o, amountOverride: o.grandTotal, subtitleOverride: 'Cash · ${qbFriendlyDate(o.deliveredAt ?? o.createdAt)}'))
                        .toList(),
                  ),
                ),
              const SizedBox(height: 14),
              const RCard(
                child: Column(
                  children: [
                    RInfoRow(icon: Icons.storefront_outlined, label: 'Hand over at', value: DeliveryConfig.defaultStoreName),
                    RInfoRow(icon: Icons.info_outline_rounded, label: 'How', value: 'Give the cash to the store manager at the end of your shift and get it counted.'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
