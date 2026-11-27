import 'package:flutter/material.dart';
import '../../../core/config/delivery_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../controllers/rider_session.dart';
import '../widgets/rider_helpers.dart';
import '../widgets/rider_ui.dart';
import 'delivery_flow_screens.dart';
import 'earnings_screens.dart';
import 'orders_screens.dart';
import 'profile_screens.dart';
import 'rider_login_screen.dart';

/// Main rider app shell: Home · Orders · Earnings · Profile.
/// Owns live sync and pops up new delivery requests as they arrive.
class RiderShell extends StatefulWidget {
  final int initialTab;
  /// Set false in tests that drive the request screen manually.
  final bool autoOpenRequests;
  const RiderShell({super.key, this.initialTab = 0, this.autoOpenRequests = true});

  @override
  State<RiderShell> createState() => _RiderShellState();
}

class _RiderShellState extends State<RiderShell> {
  late int _tab = widget.initialTab;
  final _session = RiderSession();
  final Set<String> _announced = {};

  @override
  void initState() {
    super.initState();
    _session.startSync();
    _session.addListener(_onSession);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSession());
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _session.stopSync();
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    if (!_session.isLoggedIn) {
      Navigator.of(context).pushAndRemoveUntil(riderRoute(const RiderLoginScreen(autoRestore: false)), (r) => false);
      return;
    }
    final req = _session.pendingRequest;
    final isTop = ModalRoute.of(context)?.isCurrent ?? false;
    if (widget.autoOpenRequests && req != null && isTop && _announced.add(req.id)) {
      Navigator.of(context).push(riderRoute(NewDeliveryRequestScreen(orderId: req.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      RiderHomeTab(onOpenTab: (i) => setState(() => _tab = i)),
      const RiderOrdersTab(),
      const RiderEarningsTab(),
      const RiderProfileTab(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: AppColors.primaryLight,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (s) => TextStyle(
              fontSize: 11.5,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
              color: s.contains(WidgetState.selected) ? AppColors.primaryDeep : AppColors.textSecondary,
            ),
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: NavigationBar(
            height: 66,
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: AppColors.primaryDeep), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded, color: AppColors.primaryDeep), label: 'Orders'),
              NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: AppColors.primaryDeep), label: 'Earnings'),
              NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: AppColors.primaryDeep), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

/// 2. Rider Home Dashboard.
class RiderHomeTab extends StatelessWidget {
  final ValueChanged<int> onOpenTab;
  const RiderHomeTab({super.key, required this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    final session = RiderSession();
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final rider = session.rider;
        if (rider == null) return const SizedBox.shrink();
        final request = session.pendingRequest;
        final active = session.activeOrder;
        final today = session.earnings(RiderPeriod.day);
        return Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => session.refresh(force: true),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _Header(session: session, today: today, onOpenTab: onOpenTab)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(kRiderGutter, 0, kRiderGutter, 24),
                  sliver: SliverList.list(children: [
                    if (request != null) ...[
                      const SizedBox(height: 16),
                      _NewRequestBanner(order: request),
                    ],
                    if (active != null) ...[
                      RSectionTitle('Active delivery', action: 'View all', onAction: () => onOpenTab(1)),
                      _ActiveCard(order: active),
                    ] else if (request == null) ...[
                      const SizedBox(height: 16),
                      _IdleCard(online: !rider.isOffline),
                    ],
                    const RSectionTitle('Today at a glance'),
                    Row(
                      children: [
                        Expanded(
                          child: RStatTile(
                            key: const ValueKey('stat_completed'),
                            value: '${today.count}',
                            label: 'Completed',
                            icon: Icons.task_alt_rounded,
                            onTap: () => onOpenTab(1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RStatTile(
                            key: const ValueKey('stat_pending'),
                            value: '${session.activeDeliveries.length}',
                            label: 'Pending',
                            icon: Icons.pending_actions_rounded,
                            tint: AppColors.accentLight,
                            ink: AppColors.accentInk,
                            onTap: () => onOpenTab(1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RStatTile(
                            value: RiderFormat.duration(session.onlineTimeToday),
                            label: 'Online time',
                            icon: Icons.timer_outlined,
                            tint: AppColors.infoLight,
                            ink: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                    const RSectionTitle('Delivery performance'),
                    _PerformanceCard(perf: session.performance),
                    if (session.codCashToday > 0) ...[
                      const SizedBox(height: 14),
                      RCard(
                        onTap: () => Navigator.of(context).push(riderRoute(const RiderCashCollectedScreen())),
                        color: AppColors.accentLight,
                        borderColor: AppColors.accentBorder,
                        child: Row(
                          children: [
                            const Icon(Icons.payments_outlined, color: AppColors.accentInk),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('COD cash collected: ${qbRupees(session.codCashToday)}',
                                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accentInk)),
                                  const SizedBox(height: 2),
                                  const Text('Hand it over at the store before end of shift',
                                      style: TextStyle(fontSize: 12, color: AppColors.accentInk)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.accentInk),
                          ],
                        ),
                      ),
                    ],
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final RiderSession session;
  final EarningsSummary today;
  final ValueChanged<int> onOpenTab;
  const _Header({required this.session, required this.today, required this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    final rider = session.rider!;
    final online = !rider.isOffline;
    final busy = session.activeOrder != null || session.pendingRequest != null;
    final hour = DateTime.now().hour;
    final greet = hour < 12 ? 'Good morning,' : (hour < 17 ? 'Good afternoon,' : 'Good evening,');
    final initials = rider.name.trim().split(RegExp(r'\s+')).take(2).map((p) => p[0].toUpperCase()).join();
    final unread = session.unreadNotifications;

    return Container(
      padding: EdgeInsets.fromLTRB(kRiderGutter, MediaQuery.paddingOf(context).top + 14, kRiderGutter, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: AppColors.accent,
                child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greet, style: const TextStyle(color: Color(0xFFCFEBD9), fontSize: 12)),
                    Text(rider.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              _HeaderIcon(
                icon: Icons.notifications_none_rounded,
                badge: unread > 0,
                tooltip: 'Notifications',
                onTap: () => Navigator.of(context).push(riderRoute(const RiderNotificationsScreen())),
              ),
              const SizedBox(width: 8),
              _HeaderIcon(
                icon: Icons.support_agent_rounded,
                tooltip: 'Help & support',
                onTap: () => Navigator.of(context).push(riderRoute(const RiderSupportScreen())),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: busy ? AppColors.warning : (online ? AppColors.primaryAccent : AppColors.textMuted),
                    shape: BoxShape.circle,
                    boxShadow: online ? [BoxShadow(color: AppColors.primaryAccent.withValues(alpha: 0.5), blurRadius: 8)] : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        busy ? 'On a delivery' : (online ? 'You\'re online' : 'You\'re offline'),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                      Text(
                        busy
                            ? 'Complete it to receive the next order'
                            : (online ? 'Receiving orders near ${DeliveryConfig.defaultStoreName}' : 'Go online to start receiving orders'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  key: const ValueKey('rider_duty_switch'),
                  value: online,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  onChanged: (v) async {
                    final err = await session.setOnline(v);
                    if (!context.mounted) return;
                    if (err != null) {
                      riderToast(context, err, error: true);
                    } else {
                      riderToast(context, v ? 'You\'re online. Ready for orders!' : 'You\'re offline.');
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => onOpenTab(2),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TODAY\'S EARNINGS',
                            style: TextStyle(color: Color(0xFFCFEBD9), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(qbRupees(today.total),
                            key: const ValueKey('today_earnings'),
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
                        Text('${today.count} ${today.count == 1 ? 'delivery' : 'deliveries'} · ${qbRupees(today.tips)} tips',
                            style: const TextStyle(color: Color(0xFFCFEBD9), fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      children: [
                        Text('Details', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark, fontSize: 12.5)),
                        Icon(Icons.chevron_right_rounded, color: AppColors.primaryDark, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final bool badge;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderIcon({required this.icon, this.badge = false, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              if (badge)
                Positioned(
                  top: 9,
                  right: 10,
                  child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewRequestBanner extends StatelessWidget {
  final OrderModel order;
  const _NewRequestBanner({required this.order});

  @override
  Widget build(BuildContext context) {
    final km = RiderFormat.dropKm(order);
    final pay = DeliveryConfig.defaultPerDeliveryEarning;
    return RCard(
      key: const ValueKey('new_request_banner'),
      onTap: () => Navigator.of(context).push(riderRoute(NewDeliveryRequestScreen(orderId: order.id))),
      borderColor: AppColors.accent,
      color: AppColors.accentLight,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.notifications_active_rounded, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('New delivery request!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(
                  [
                    order.orderNumber,
                    if (km != null) RiderFormat.km(km),
                    qbRupees(pay) + (order.tipAmount > 0 ? ' + ${qbRupees(order.tipAmount)} tip' : ''),
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textBody),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.accentInk),
        ],
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  final OrderModel order;
  const _ActiveCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final eta = RiderFormat.etaMinutes(order);
    final stage = RiderFormat.stageOf(order);
    final toStore = stage == 'accepted' || stage == 'reached_store';
    return RCard(
      key: const ValueKey('active_delivery_card'),
      padding: EdgeInsets.zero,
      onTap: () => openDeliveryStage(context, order),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Flexible(child: Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                const SizedBox(width: 8),
                RStatusPill(order),
                const Spacer(),
                if (eta != null && !toStore)
                  Text('~$eta min', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryDeep)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: RRouteMap(height: 120, radius: 14, toStore: toStore),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Icon(toStore ? Icons.storefront_rounded : Icons.location_on_rounded,
                    color: toStore ? AppColors.primaryDark : const Color(0xFFE65100), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(toStore ? 'Pick up at ${DeliveryConfig.defaultStoreName}' : 'Deliver to customer',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(RiderFormat.shortAddress(order),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (order.isCod)
                  QbPill(label: 'Collect ${qbRupees(order.grandTotal)}', background: AppColors.accentLight, foreground: AppColors.accentInk),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdleCard extends StatelessWidget {
  final bool online;
  const _IdleCard({required this.online});

  @override
  Widget build(BuildContext context) {
    return RCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: online ? AppColors.primaryLight : AppColors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
            child: Icon(online ? Icons.radar_rounded : Icons.power_settings_new_rounded,
                color: online ? AppColors.primaryDeep : AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              online
                  ? 'Waiting for orders. New requests from the store pop up here instantly.'
                  : 'You\'re offline. Switch on duty above to receive delivery requests.',
              style: const TextStyle(fontSize: 13, color: AppColors.textBody, fontWeight: FontWeight.w600, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  final RiderPerformance perf;
  const _PerformanceCard({required this.perf});

  @override
  Widget build(BuildContext context) {
    Widget metric(String value, String label, double? pct, Color color) {
      return Expanded(
        child: Column(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: pct ?? 0,
                      strokeWidth: 5,
                      backgroundColor: AppColors.surfaceMuted,
                      color: color,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return RCard(
      child: Column(
        children: [
          Row(
            children: [
              metric(perf.rating.toStringAsFixed(1), 'Rating', perf.rating / 5, AppColors.accent),
              metric(RiderFormat.pct(perf.acceptanceRate), 'Acceptance', perf.acceptanceRate, AppColors.primary),
              metric(RiderFormat.pct(perf.onTimeRate), 'On-time', perf.onTimeRate, AppColors.info),
              metric(RiderFormat.pct(perf.completionRate), 'Completion', perf.completionRate, AppColors.primaryAccent),
            ],
          ),
          const Divider(height: 26),
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, size: 18, color: AppColors.accentInk),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${perf.lifetimeDeliveries} lifetime deliveries',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textBody),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Notifications feed built from the rider's real order events.
class RiderNotificationsScreen extends StatefulWidget {
  const RiderNotificationsScreen({super.key});

  @override
  State<RiderNotificationsScreen> createState() => _RiderNotificationsScreenState();
}

class _RiderNotificationsScreenState extends State<RiderNotificationsScreen> {
  /// Newest-first feed: the first [_unreadCount] items were unread on open.
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    final s = RiderSession();
    _unreadCount = s.unreadNotifications;
    s.markNotificationsRead();
  }

  @override
  Widget build(BuildContext context) {
    final session = RiderSession();
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final items = session.notifications;
        return Scaffold(
          appBar: AppBar(title: const Text('Notifications')),
          body: items.isEmpty
              ? const _EmptyState(icon: Icons.notifications_none_rounded, text: 'No notifications yet.\nDelivery requests and payouts show up here.')
              : ListView.separated(
                  padding: const EdgeInsets.all(kRiderGutter),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final n = items[i];
                    final (icon, tint, ink) = switch (n.kind) {
                      'delivered' => (Icons.task_alt_rounded, AppColors.primaryLight, AppColors.primaryDeep),
                      'cash' => (Icons.payments_outlined, AppColors.accentLight, AppColors.accentInk),
                      'cancelled' => (Icons.cancel_outlined, AppColors.errorLight, AppColors.error),
                      _ => (Icons.delivery_dining_rounded, AppColors.infoLight, AppColors.info),
                    };
                    final unread = i < _unreadCount;
                    final order = n.orderId != null ? session.orderById(n.orderId!) : null;
                    return RCard(
                      color: unread ? AppColors.primaryTint : Colors.white,
                      padding: const EdgeInsets.all(14),
                      onTap: order == null
                          ? null
                          : () => order.status == OrderStatus.delivered || order.status == OrderStatus.cancelled
                              ? Navigator.of(context).push(riderRoute(RiderOrderHistoryDetailScreen(orderId: order.id)))
                              : openDeliveryStage(context, order),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)),
                            child: Icon(icon, color: ink, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 3),
                                Text(n.body, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.35)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(qbAge(n.time), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.borderStrong),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
