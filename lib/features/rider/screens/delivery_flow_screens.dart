import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/config/delivery_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../controllers/rider_session.dart';
import '../widgets/rider_helpers.dart';
import '../widgets/rider_ui.dart';
import 'rider_login_screen.dart';

/// Opens the screen matching the order's current delivery stage.
void openDeliveryStage(BuildContext context, OrderModel order) {
  final page = switch (RiderFormat.stageOf(order)) {
    'assigned' => NewDeliveryRequestScreen(orderId: order.id),
    'accepted' => AcceptedOrderScreen(orderId: order.id),
    'reached_store' => StorePickupScreen(orderId: order.id),
    _ => CustomerDeliveryScreen(orderId: order.id),
  };
  Navigator.of(context).push(riderRoute(page));
}

void _replace(BuildContext context, Widget page) => Navigator.of(context).pushReplacement(riderRoute(page));
void _push(BuildContext context, Widget page) => Navigator.of(context).push(riderRoute(page));
void _home(BuildContext context) => Navigator.of(context).popUntil((r) => r.isFirst);

/// Rebuilds with the latest copy of [orderId]; shows an "ended" state if the
/// order was cancelled / un-assigned while the screen was open.
class _OrderScope extends StatelessWidget {
  final String orderId;
  final Widget Function(BuildContext context, OrderModel order) builder;
  final bool allowTerminal;
  const _OrderScope({required this.orderId, required this.builder, this.allowTerminal = false});

  @override
  Widget build(BuildContext context) {
    final session = RiderSession();
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final order = session.orderById(orderId);
        if (order == null) {
          return const _OrderEnded(
            title: 'Delivery no longer assigned',
            body: 'This order was returned to the store and is no longer assigned to you.',
          );
        }
        if (!allowTerminal && order.status == OrderStatus.cancelled) {
          return _OrderEnded(
            title: 'Order cancelled',
            body: '${order.orderNumber} was cancelled${order.cancellationReason != null ? ': ${order.cancellationReason}' : ''}. '
                'If you already picked it up, return the items to the store.',
          );
        }
        return builder(context, order);
      },
    );
  }
}

class _OrderEnded extends StatelessWidget {
  final String title;
  final String body;
  const _OrderEnded({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline_rounded, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
            const SizedBox(height: 24),
            RPrimaryButton(label: 'Back to home', icon: Icons.home_rounded, onPressed: () => _home(context)),
          ],
        ),
      ),
    );
  }
}

AppBar _flowAppBar(BuildContext context, String title, OrderModel order) => AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          Text(order.orderNumber, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _push(context, DeliveryIssueScreen(orderId: order.id)),
          icon: const Icon(Icons.report_gmailerrorred_rounded, size: 18, color: AppColors.error),
          label: const Text('Issue', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w800)),
        ),
      ],
    );

Future<void> _guard(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } on RiderException catch (e) {
    if (context.mounted) riderToast(context, e.message, error: true);
  }
}

int _itemCount(OrderModel o) => o.items.fold<int>(0, (s, i) => s + i.quantity);

// =============================================================================
// 3.1 New Delivery Request  ·  3.3 Accept / Reject
// =============================================================================

class NewDeliveryRequestScreen extends StatefulWidget {
  final String orderId;
  const NewDeliveryRequestScreen({super.key, required this.orderId});

  @override
  State<NewDeliveryRequestScreen> createState() => _NewDeliveryRequestScreenState();
}

class _NewDeliveryRequestScreenState extends State<NewDeliveryRequestScreen> {
  final _session = RiderSession();
  Timer? _timer;
  late DateTime _deadline;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final o = _session.orderById(widget.orderId);
    _deadline = o != null ? _session.requestDeadline(o) : _session.clock().add(DeliveryConfig.requestResponseWindow);
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _left => _deadline.difference(_session.clock()).inSeconds.clamp(0, DeliveryConfig.requestResponseWindow.inSeconds);

  Future<void> _tick() async {
    if (!mounted) return;
    final o = _session.orderById(widget.orderId);
    if (o == null || RiderFormat.stageOf(o) != 'assigned') {
      _timer?.cancel();
      return; // handled by _OrderScope / already accepted
    }
    if (_left <= 0 && !_busy) {
      _timer?.cancel();
      _busy = true;
      await _session.decline(o, 'No response (timed out)');
      if (mounted) {
        Navigator.of(context).pop();
        riderToast(context, 'Request timed out and was returned to the store');
      }
      return;
    }
    setState(() {});
  }

  Future<void> _accept(OrderModel o) async {
    setState(() => _busy = true);
    await _guard(context, () async {
      await _session.accept(o);
      if (mounted) _replace(context, AcceptedOrderScreen(orderId: o.id));
    });
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _reject(OrderModel o) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => const _RejectReasonSheet(),
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    _timer?.cancel();
    await _guard(context, () async {
      await _session.decline(o, reason);
      if (mounted) {
        Navigator.of(context).pop();
        riderToast(context, 'Request declined · returned to the store');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _OrderScope(
      orderId: widget.orderId,
      builder: (context, o) {
        if (RiderFormat.stageOf(o) != 'assigned') {
          return const _OrderEnded(title: 'Request already handled', body: 'This delivery request is no longer waiting for a response.');
        }
        final total = DeliveryConfig.requestResponseWindow.inSeconds;
        final km = RiderFormat.dropKm(o);
        final eta = RiderFormat.etaMinutes(o);
        final pay = DeliveryConfig.defaultPerDeliveryEarning;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('New delivery request')),
          body: ListView(
            padding: const EdgeInsets.all(kRiderGutter),
            children: [
              RCard(
                color: AppColors.primaryDark,
                borderColor: AppColors.primaryDark,
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: _left / total,
                              strokeWidth: 5,
                              color: AppColors.accent,
                              backgroundColor: Colors.white24,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Text('${_left}s', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('YOU EARN', style: TextStyle(color: Color(0xFFCFEBD9), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                          Text(qbRupees(pay + o.tipAmount), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                          Text(
                            o.tipAmount > 0 ? '${qbRupees(pay)} delivery + ${qbRupees(o.tipAmount)} customer tip' : '${qbRupees(pay)} delivery pay',
                            style: const TextStyle(color: Color(0xFFCFEBD9), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const RRouteMap(height: 170),
              const SizedBox(height: 12),
              RCard(
                child: Column(
                  children: [
                    _routeStop(
                      icon: Icons.storefront_rounded,
                      color: AppColors.primaryDark,
                      title: 'PICKUP',
                      name: DeliveryConfig.defaultStoreName,
                      sub: 'Pincode ${DeliveryConfig.defaultStorePincode}',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 15),
                      child: Row(children: [Container(width: 2, height: 22, color: AppColors.border)]),
                    ),
                    _routeStop(
                      icon: Icons.home_rounded,
                      color: const Color(0xFFE65100),
                      title: km != null ? 'DROP · ${RiderFormat.km(km)} from store' : 'DROP',
                      name: RiderFormat.area(o),
                      sub: [
                        if (o.address != null) 'Pincode ${o.address!.pincode}',
                        if ((o.address?.landmark ?? '').isNotEmpty) 'near ${o.address!.landmark}',
                      ].join(' · '),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _chip(Icons.shopping_basket_outlined, _itemCount(o) > 0 ? '${_itemCount(o)} items' : 'Items')),
                  const SizedBox(width: 8),
                  Expanded(child: _chip(Icons.schedule_rounded, eta != null ? '~$eta min' : '${o.estimatedDeliveryMinutes} min ETA')),
                  const SizedBox(width: 8),
                  Expanded(child: _chip(Icons.payments_outlined, o.isCod ? 'COD ${qbRupees(o.grandTotal)}' : 'Prepaid')),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _push(context, RiderOrderDetailsScreen(orderId: o.id)),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('View full order details', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          bottomNavigationBar: RBottomBar(children: [
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: ROutlineButton(label: 'Reject', color: AppColors.error, onPressed: _busy ? null : () => _reject(o)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RPrimaryButton(
                    label: 'Accept order',
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: _busy ? null : () => _accept(o),
                  ),
                ),
              ],
            ),
          ]),
        );
      },
    );
  }

  Widget _chip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: qbCard(radius: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.textBody),
            const SizedBox(width: 5),
            Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
          ],
        ),
      );
}

Widget _routeStop({required IconData icon, required Color color, required String title, required String name, required String sub}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, size: 17, color: Colors.white),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.4)),
            const SizedBox(height: 2),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35)),
          ],
        ),
      ),
    ],
  );
}

class _RejectReasonSheet extends StatefulWidget {
  const _RejectReasonSheet();

  @override
  State<_RejectReasonSheet> createState() => _RejectReasonSheetState();
}

class _RejectReasonSheetState extends State<_RejectReasonSheet> {
  static const _reasons = ['Too far from my location', 'Vehicle issue', 'Ending my shift', 'Bad weather / unsafe route', 'Other'];
  String? _sel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why are you rejecting?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('The order goes back to the store for another partner. Frequent rejections lower your acceptance rate.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ..._reasons.map((r) => InkWell(
                  onTap: () => setState(() => _sel = r),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        QbRadioDot(selected: _sel == r),
                        const SizedBox(width: 12),
                        Expanded(child: Text(r, style: const TextStyle(fontWeight: FontWeight.w700))),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 12),
            RPrimaryButton(
              label: 'Reject request',
              color: AppColors.error,
              onPressed: _sel == null ? null : () => Navigator.of(context).pop(_sel),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 3.2 Order Details
// =============================================================================

class RiderOrderDetailsScreen extends StatelessWidget {
  final String orderId;
  const RiderOrderDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return _OrderScope(
      orderId: orderId,
      allowTerminal: true,
      builder: (context, d) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text('Order ${d.orderNumber}')),
        body: ListView(
          padding: const EdgeInsets.all(kRiderGutter),
          children: [
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(_itemCount(d) > 0 ? '${_itemCount(d)} items' : 'Items', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const Spacer(),
                      RStatusPill(d),
                    ],
                  ),
                  const Divider(height: 22),
                  if (d.items.isEmpty)
                    const Text('Item list is available at the store counter.', style: TextStyle(color: AppColors.textSecondary)),
                  ...d.items.map((i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                              child: Text('${i.quantity}×', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.primaryDeep)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(i.product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(i.variant.unit, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                            Text(qbRupees(i.totalPrice), style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RCard(
              child: Column(
                children: [
                  _billRow('Item total', qbRupees(d.itemTotal)),
                  if (d.discountAmount > 0) _billRow('Discount', '−${qbRupees(d.discountAmount)}'),
                  _billRow('Delivery fee', d.deliveryFee > 0 ? qbRupees(d.deliveryFee) : 'FREE'),
                  if (d.packagingFee > 0) _billRow('Packaging fee', qbRupees(d.packagingFee)),
                  if (d.tipAmount > 0) _billRow('Tip for you', qbRupees(d.tipAmount)),
                  const Divider(height: 20),
                  _billRow('Order total', qbRupees(d.grandTotal), bold: true),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: d.isCod ? AppColors.accentLight : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(d.isCod ? Icons.payments_outlined : Icons.verified_rounded, color: d.isCod ? AppColors.accentInk : AppColors.primaryDeep),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            d.isCod ? 'Cash on delivery — collect ${qbRupees(d.grandTotal)} from customer' : 'Paid online — do not collect cash',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: d.isCod ? AppColors.accentInk : AppColors.primaryDeep),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if ((d.deliveryInstructions ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              RCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sticky_note_2_outlined, color: AppColors.info),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Delivery instructions', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(d.deliveryInstructions!, style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Widget _billRow(String l, String v, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(l, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, color: bold ? AppColors.textPrimary : AppColors.textBody)),
          const Spacer(),
          Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700)),
        ],
      ),
    );

// =============================================================================
// 3.4 Accepted Order — heading to the dark store
// =============================================================================

class AcceptedOrderScreen extends StatelessWidget {
  final String orderId;
  const AcceptedOrderScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return _OrderScope(
      orderId: orderId,
      builder: (context, o) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: _flowAppBar(context, 'Go to store', o),
        body: ListView(
          padding: const EdgeInsets.all(kRiderGutter),
          children: [
            RCard(child: RDeliveryStepper(step: RiderFormat.stepOf(o))),
            const SizedBox(height: 12),
            const RRouteMap(height: 220, toStore: true),
            const SizedBox(height: 12),
            RCard(
              child: Column(
                children: [
                  _routeStop(
                    icon: Icons.storefront_rounded,
                    color: AppColors.primaryDark,
                    title: 'PICKUP FROM',
                    name: DeliveryConfig.defaultStoreName,
                    sub: 'Pincode ${DeliveryConfig.defaultStorePincode}',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      RRoundAction(icon: Icons.call_rounded, label: 'Call store', onTap: () => RiderIntents.callStore(context)),
                      RRoundAction(
                        icon: Icons.navigation_rounded,
                        label: 'Navigate',
                        onTap: () => _push(context, MapNavigationScreen(orderId: o.id, toStore: true)),
                      ),
                      RRoundAction(
                        icon: Icons.receipt_long_rounded,
                        label: 'Order',
                        onTap: () => _push(context, RiderOrderDetailsScreen(orderId: o.id)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: RBottomBar(children: [
          RSlideToConfirm(
            key: const ValueKey('slide_reached_store'),
            label: 'Slide when you reach store',
            onConfirmed: () => _guard(context, () async {
              await RiderSession().reachedStore(o);
              if (context.mounted) _replace(context, StorePickupScreen(orderId: o.id));
            }),
          ),
        ]),
      ),
    );
  }
}

// =============================================================================
// 3.5 Store Pickup Details
// =============================================================================

class StorePickupScreen extends StatelessWidget {
  final String orderId;
  const StorePickupScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return _OrderScope(
      orderId: orderId,
      builder: (context, o) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: _flowAppBar(context, 'Pick up order', o),
        body: ListView(
          padding: const EdgeInsets.all(kRiderGutter),
          children: [
            RCard(child: RDeliveryStepper(step: RiderFormat.stepOf(o))),
            const SizedBox(height: 12),
            RCard(
              color: AppColors.primaryTint,
              borderColor: AppColors.primary.withValues(alpha: 0.35),
              child: Column(
                children: [
                  const Text('SHOW THIS AT THE PICKUP COUNTER',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primaryDeep, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  FittedBox(
                    child: Text(o.orderNumber,
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.primaryDark)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _pickupFact(Icons.shopping_basket_outlined, 'Items', _itemCount(o) > 0 ? '${_itemCount(o)}' : '—')),
                const SizedBox(width: 10),
                Expanded(child: _pickupFact(Icons.payments_outlined, o.isCod ? 'Collect (COD)' : 'Payment', o.isCod ? qbRupees(o.grandTotal) : 'Prepaid')),
                const SizedBox(width: 10),
                Expanded(child: _pickupFact(Icons.schedule_rounded, 'Ordered', qbTime(o.createdAt))),
              ],
            ),
            const SizedBox(height: 12),
            RCard(
              child: Column(
                children: [
                  const RInfoRow(icon: Icons.storefront_outlined, label: 'Store', value: DeliveryConfig.defaultStoreName),
                  RInfoRow(
                    icon: Icons.support_agent_outlined,
                    label: 'Store support',
                    value: DeliveryConfig.storeSupportPhone.isEmpty ? 'Ask the counter staff' : DeliveryConfig.storeSupportPhone,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Check every item and the seal on each bag before confirming pickup.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.info, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: RBottomBar(children: [
          RPrimaryButton(
            label: 'Verify items',
            icon: Icons.checklist_rounded,
            onPressed: () => _replace(context, PickupConfirmationScreen(orderId: o.id)),
          ),
        ]),
      ),
    );
  }

  Widget _pickupFact(IconData icon, String label, String value) => RCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.textBody),
            const SizedBox(height: 8),
            FittedBox(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          ],
        ),
      );
}

// =============================================================================
// 3.6 Pickup Confirmation — item checklist
// =============================================================================

class PickupConfirmationScreen extends StatefulWidget {
  final String orderId;
  const PickupConfirmationScreen({super.key, required this.orderId});

  @override
  State<PickupConfirmationScreen> createState() => _PickupConfirmationScreenState();
}

class _PickupConfirmationScreenState extends State<PickupConfirmationScreen> {
  List<bool>? _checked;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return _OrderScope(
      orderId: widget.orderId,
      builder: (context, o) {
        // Orders without an item list get a single "all bags received" check.
        final labels = o.items.isEmpty
            ? [('All bags for ${o.orderNumber}', 'Sealed and handed over by the store', 0)]
            : [for (final i in o.items) (i.product.name, i.variant.unit, i.quantity)];
        if (_checked == null || _checked!.length != labels.length) _checked = List.filled(labels.length, false);
        final checked = _checked!;
        final done = checked.where((c) => c).length;
        final all = done == checked.length;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _flowAppBar(context, 'Confirm pickup', o),
          body: ListView(
            padding: const EdgeInsets.all(kRiderGutter),
            children: [
              Row(
                children: [
                  Text('$done of ${checked.length} checked', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => checked.fillRange(0, checked.length, true)),
                    child: const Text('Check all', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: checked.isEmpty ? 0 : done / checked.length,
                  minHeight: 6,
                  color: AppColors.primary,
                  backgroundColor: AppColors.border,
                ),
              ),
              const SizedBox(height: 14),
              RCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: List.generate(labels.length, (i) {
                    final (name, unit, qty) = labels[i];
                    return CheckboxListTile(
                      value: checked[i],
                      onChanged: (v) => setState(() => checked[i] = v ?? false),
                      activeColor: AppColors.primary,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Text(unit, style: const TextStyle(fontSize: 12)),
                      secondary: qty > 0 ? Text('×$qty', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)) : null,
                    );
                  }),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _push(context, DeliveryIssueScreen(orderId: o.id, preselect: DeliveryIssueScreen.missingItems)),
                icon: const Icon(Icons.remove_shopping_cart_outlined, color: AppColors.error, size: 18),
                label: const Text('An item is missing or damaged', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          bottomNavigationBar: RBottomBar(children: [
            RSlideToConfirm(
              key: const ValueKey('slide_confirm_pickup'),
              label: all ? 'Slide to confirm pickup' : 'Check all items to continue',
              enabled: all && !_busy,
              onConfirmed: () async {
                setState(() => _busy = true);
                await _guard(context, () async {
                  await RiderSession().confirmPickup(o);
                  if (context.mounted) _replace(context, CustomerDeliveryScreen(orderId: o.id));
                });
                if (mounted) setState(() => _busy = false);
              },
            ),
          ]),
        );
      },
    );
  }
}

// =============================================================================
// 3.7 Customer Delivery Details
// =============================================================================

class CustomerDeliveryScreen extends StatelessWidget {
  final String orderId;
  const CustomerDeliveryScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return _OrderScope(
      orderId: orderId,
      builder: (context, o) {
        if (o.status == OrderStatus.delivered) {
          return DeliverySuccessScreen(orderId: o.id);
        }
        final km = RiderFormat.dropKm(o);
        final eta = RiderFormat.etaMinutes(o);
        final issue = RiderFormat.stageOf(o) == 'issue_reported';
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _flowAppBar(context, 'Deliver to customer', o),
          body: ListView(
            padding: const EdgeInsets.all(kRiderGutter),
            children: [
              if (issue) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.errorBorder)),
                  child: const Row(
                    children: [
                      Icon(Icons.report_gmailerrorred_rounded, color: AppColors.error),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('Issue reported. The store team will reassign or cancel this order — or continue if the problem is solved.',
                            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              RCard(child: RDeliveryStepper(step: RiderFormat.stepOf(o))),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _push(context, MapNavigationScreen(orderId: o.id)),
                child: RRouteMap(
                  height: 190,
                  overlay: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: QbPill(
                        label: 'Open navigation',
                        background: AppColors.primaryDark,
                        foreground: Colors.white,
                        icon: Icons.navigation_rounded,
                        fontSize: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<CustomerContact>(
                future: CustomerContact.load(o),
                initialData: CustomerContact.fallback(o),
                builder: (context, snap) {
                  final c = snap.data!;
                  return RCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.secondaryLight,
                              child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFE65100))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
                                  Text(
                                    [if (km != null) RiderFormat.km(km), if (eta != null) 'ETA ~$eta min'].join(' · ').ifEmpty('Customer address below'),
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            RRoundAction(
                              icon: Icons.call_rounded,
                              label: 'Call',
                              onTap: () => c.phone != null
                                  ? RiderIntents.call(context, c.phone)
                                  : RiderIntents.callStore(context),
                            ),
                            RRoundAction(icon: Icons.sms_outlined, label: 'Message', onTap: () => RiderIntents.sms(context, c.phone)),
                            RRoundAction(
                              icon: Icons.navigation_rounded,
                              label: 'Navigate',
                              onTap: () => _push(context, MapNavigationScreen(orderId: o.id)),
                            ),
                          ],
                        ),
                        if (c.phone == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text('Customer number isn\'t shared — calls go to store support.',
                                textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                          ),
                        const Divider(height: 24),
                        RInfoRow(icon: Icons.home_outlined, label: 'Address', value: RiderFormat.fullAddress(o)),
                        if ((o.address?.landmark ?? '').isNotEmpty)
                          RInfoRow(icon: Icons.flag_outlined, label: 'Landmark', value: o.address!.landmark!),
                        if ((o.deliveryInstructions ?? '').trim().isNotEmpty)
                          RInfoRow(icon: Icons.sticky_note_2_outlined, label: 'Instructions', value: o.deliveryInstructions!, iconColor: AppColors.info),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              RCard(
                onTap: () => _push(context, RiderOrderDetailsScreen(orderId: o.id)),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_itemCount(o) > 0 ? '${_itemCount(o)} items' : 'Order items', style: const TextStyle(fontWeight: FontWeight.w800))),
                    if (o.isCod)
                      QbPill(label: 'Collect ${qbRupees(o.grandTotal)}', background: AppColors.accentLight, foreground: AppColors.accentInk, fontSize: 12),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: RBottomBar(children: [
            RSlideToConfirm(
              key: const ValueKey('slide_at_doorstep'),
              label: 'Slide when at doorstep',
              color: const Color(0xFFE65100),
              onConfirmed: () => _push(context, DeliveryOtpScreen(orderId: o.id)),
            ),
          ]),
        );
      },
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

// =============================================================================
// 3.8 Map and Navigation
// =============================================================================

class MapNavigationScreen extends StatelessWidget {
  final String orderId;
  final bool toStore;
  const MapNavigationScreen({super.key, required this.orderId, this.toStore = false});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return _OrderScope(
      orderId: orderId,
      builder: (context, o) {
        final km = toStore ? null : RiderFormat.dropKm(o);
        final eta = toStore ? null : RiderFormat.etaMinutes(o);
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: RRouteMap(height: double.infinity, radius: 0, toStore: toStore)),
              Positioned(
                top: top + 10,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).pop()),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            Icon(toStore ? Icons.storefront_rounded : Icons.home_rounded, color: AppColors.accent, size: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(toStore ? 'Head to the dark store' : 'Head to the customer',
                                      style: const TextStyle(color: Color(0xFFCFEBD9), fontSize: 12, fontWeight: FontWeight.w700)),
                                  Text(toStore ? DeliveryConfig.defaultStoreName : RiderFormat.shortAddress(o),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + MediaQuery.paddingOf(context).bottom),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(eta != null ? '~$eta min' : (toStore ? 'Dark store' : 'Customer'),
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primaryDeep)),
                                Text(km != null ? '${RiderFormat.km(km)} straight-line from store' : 'Live route & traffic in Google Maps',
                                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          RRoundAction(
                            icon: Icons.call_rounded,
                            label: toStore ? 'Store' : 'Call',
                            onTap: () async {
                              if (toStore) return RiderIntents.callStore(context);
                              final c = await CustomerContact.load(o);
                              if (!context.mounted) return;
                              c.phone != null ? RiderIntents.call(context, c.phone) : RiderIntents.callStore(context);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      RPrimaryButton(
                        label: 'Start navigation in Google Maps',
                        icon: Icons.navigation_rounded,
                        onPressed: () => RiderIntents.navigate(context, to: o, toStore: toStore),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// 3.9 Delivery OTP Verification
// =============================================================================

class DeliveryOtpScreen extends StatefulWidget {
  final String orderId;
  const DeliveryOtpScreen({super.key, required this.orderId});

  @override
  State<DeliveryOtpScreen> createState() => _DeliveryOtpScreenState();
}

class _DeliveryOtpScreenState extends State<DeliveryOtpScreen> {
  String _otp = '';
  bool _cashCollected = false;
  bool _verifying = false;
  String? _error;
  bool _locked = false;

  void _tap(String k) {
    if (_locked || _verifying) return;
    setState(() {
      _error = null;
      if (k == '⌫') {
        if (_otp.isNotEmpty) _otp = _otp.substring(0, _otp.length - 1);
      } else if (_otp.length < 4) {
        _otp += k;
      }
    });
  }

  Future<void> _verify(OrderModel o) async {
    setState(() => _verifying = true);
    final res = await RiderSession().verifyDeliveryOtp(o, _otp);
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.of(context).pushAndRemoveUntil(riderRoute(DeliverySuccessScreen(orderId: o.id)), (r) => r.isFirst);
      return;
    }
    setState(() {
      _verifying = false;
      _otp = '';
      _error = res['error'] as String? ?? 'Verification failed. Try again.';
      _locked = res['locked'] == true || res['expired'] == true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _OrderScope(
      orderId: widget.orderId,
      builder: (context, o) {
        final remaining = (DeliveryConfig.maxOtpAttempts - o.otpAttempts).clamp(0, DeliveryConfig.maxOtpAttempts);
        final locked = _locked || remaining == 0;
        final ready = _otp.length == 4 && (!o.isCod || _cashCollected) && !_verifying && !locked;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: _flowAppBar(context, 'Verify delivery', o),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: locked ? AppColors.errorLight : AppColors.primaryLight, shape: BoxShape.circle),
                        child: Icon(locked ? Icons.lock_rounded : Icons.lock_outline_rounded, size: 30,
                            color: locked ? AppColors.error : AppColors.primaryDeep),
                      ),
                      const SizedBox(height: 12),
                      Text(locked ? 'Verification locked' : 'Ask customer for the 4-digit OTP',
                          textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        locked ? 'Too many incorrect attempts. Report the issue so the store can help.' : 'Shown in the customer\'s Quick Basket app',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          final filled = i < _otp.length;
                          return Container(
                            key: ValueKey('otp_box_$i'),
                            margin: const EdgeInsets.symmetric(horizontal: 7),
                            width: 54,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: filled ? AppColors.primaryTint : AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _error != null ? AppColors.error : (i == _otp.length ? AppColors.primary : AppColors.border),
                                width: 1.6,
                              ),
                            ),
                            child: Text(filled ? _otp[i] : '', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      if (_error != null)
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 12.5))
                      else
                        Text('$remaining of ${DeliveryConfig.maxOtpAttempts} attempts left · OTP is never shown to partners',
                            textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      if (locked) ...[
                        const SizedBox(height: 14),
                        ROutlineButton(
                          label: 'Report issue to store',
                          icon: Icons.report_gmailerrorred_rounded,
                          color: AppColors.error,
                          onPressed: () => _push(context, DeliveryIssueScreen(orderId: o.id, preselect: DeliveryIssueScreen.otpLocked)),
                        ),
                      ],
                      if (o.isCod && !locked) ...[
                        const SizedBox(height: 16),
                        InkWell(
                          key: const ValueKey('cod_collected_check'),
                          onTap: () => setState(() => _cashCollected = !_cashCollected),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.accentLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _cashCollected ? AppColors.accentInk : AppColors.accentBorder),
                            ),
                            child: Row(
                              children: [
                                Icon(_cashCollected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: AppColors.accentInk),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text('I have collected ${qbRupees(o.grandTotal)} cash',
                                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accentInk)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!locked) _Keypad(onKey: _tap),
            ],
          ),
          bottomNavigationBar: RBottomBar(children: [
            RPrimaryButton(
              label: _verifying ? 'Verifying…' : 'Verify & complete delivery',
              icon: Icons.verified_rounded,
              onPressed: ready ? () => _verify(o) : null,
            ),
          ]),
        );
      },
    );
  }
}

class _Keypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  const _Keypad({required this.onKey});

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return Container(
      color: AppColors.surfaceMuted,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.6,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        children: keys.map((k) {
          if (k.isEmpty) return const SizedBox.shrink();
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              key: ValueKey('key_$k'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => onKey(k),
              child: Center(
                child: k == '⌫'
                    ? const Icon(Icons.backspace_outlined, size: 20)
                    : Text(k, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// =============================================================================
// 3.10 Delivery Successful
// =============================================================================

class DeliverySuccessScreen extends StatelessWidget {
  final String orderId;
  const DeliverySuccessScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final o = RiderSession().orderById(orderId);
    final pay = DeliveryConfig.defaultPerDeliveryEarning;
    final tip = o?.tipAmount ?? 0;
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.5, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (_, s, child) => Transform.scale(scale: s, child: child),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 70, color: AppColors.primaryDark),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Delivered!', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('${o?.orderNumber ?? 'Order'} verified with customer OTP', style: const TextStyle(color: Color(0xFFCFEBD9))),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    _billRow('Delivery pay', qbRupees(pay)),
                    if (tip > 0) _billRow('Customer tip', qbRupees(tip)),
                    const Divider(height: 20),
                    _billRow('You earned', qbRupees(pay + tip), bold: true),
                    if (o?.isCod == true) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(10)),
                        child: Text('${qbRupees(o!.grandTotal)} cash collected — hand it over at the store',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.accentInk)),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              RPrimaryButton(
                label: 'Back to home',
                color: AppColors.accent,
                foreground: AppColors.primaryDark,
                icon: Icons.home_rounded,
                onPressed: () => _home(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 3.11 Failed Delivery / Issue Reporting
// =============================================================================

class DeliveryIssueScreen extends StatefulWidget {
  final String orderId;
  final int? preselect;
  const DeliveryIssueScreen({super.key, required this.orderId, this.preselect});

  static const int otpLocked = 3;
  static const int missingItems = 4;

  static const issues = [
    (Icons.phone_disabled_rounded, 'Customer not reachable', 'Called several times, no answer'),
    (Icons.wrong_location_outlined, 'Wrong / incomplete address', 'Unable to locate the address'),
    (Icons.block_rounded, 'Customer refused order', 'Customer declined at doorstep'),
    (Icons.lock_clock_outlined, 'OTP locked / not working', 'Customer can\'t share a valid OTP'),
    (Icons.inventory_outlined, 'Damaged or missing items', 'Items missing at pickup or damaged'),
    (Icons.two_wheeler_outlined, 'Vehicle breakdown / accident', 'Need help from the store'),
  ];

  @override
  State<DeliveryIssueScreen> createState() => _DeliveryIssueScreenState();
}

class _DeliveryIssueScreenState extends State<DeliveryIssueScreen> {
  late int? _sel = widget.preselect;
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(OrderModel o) async {
    setState(() => _busy = true);
    await _guard(context, () async {
      await RiderSession().reportIssue(o, DeliveryIssueScreen.issues[_sel!].$2, _note.text);
      if (!mounted) return;
      _home(context);
      riderToast(context, 'Issue reported. The store team has been notified.');
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return _OrderScope(
      orderId: widget.orderId,
      builder: (context, o) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Report an issue')),
        body: ListView(
          padding: const EdgeInsets.all(kRiderGutter),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.errorBorder)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Reporting for ${o.orderNumber}. The store team sees this in the Admin Panel and will reassign or cancel the order.',
                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                ],
              ),
            ),
            const RSectionTitle('What went wrong?'),
            ...List.generate(DeliveryIssueScreen.issues.length, (i) {
              final (icon, title, sub) = DeliveryIssueScreen.issues[i];
              final selected = _sel == i;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RCard(
                  onTap: () => setState(() => _sel = i),
                  padding: const EdgeInsets.all(12),
                  borderColor: selected ? AppColors.primary : AppColors.border,
                  color: selected ? AppColors.primaryTint : Colors.white,
                  child: Row(
                    children: [
                      Icon(icon, color: selected ? AppColors.primaryDeep : AppColors.textBody),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      QbRadioDot(selected: selected),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 6),
            TextField(
              controller: _note,
              maxLines: 3,
              maxLength: 280,
              decoration: const InputDecoration(hintText: 'Add a note for the store (optional)'),
            ),
            const SizedBox(height: 6),
            ROutlineButton(label: 'Call store support', icon: Icons.support_agent_rounded, onPressed: () => RiderIntents.callStore(context)),
          ],
        ),
        bottomNavigationBar: RBottomBar(children: [
          RPrimaryButton(
            label: _busy ? 'Reporting…' : 'Report to store',
            color: AppColors.error,
            icon: Icons.send_rounded,
            onPressed: _sel == null || _busy ? null : () => _submit(o),
          ),
        ]),
      ),
    );
  }
}
