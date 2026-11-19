import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../services/supabase_service.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../widgets/order_card.dart';

/// Live order tracking (PRD 4.10)
///
/// Arrival countdown, route map, rider card, delivery OTP and the status
/// timeline. Status updates arrive live from the store (admin) side.
class OrderTrackingScreen extends StatefulWidget {
  final OrderModel order;

  const OrderTrackingScreen({
    super.key,
    required this.order,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late OrderModel _activeOrder;
  late int _remainingSeconds;
  late int _totalSeconds;
  Timer? _countdownTimer;
  Timer? _crossTabSyncTimer;
  late OrderStatus _currentStatus;

  @override
  void initState() {
    super.initState();
    // Resolve fresh state from SupabaseService
    final fresh = SupabaseService().getOrderById(widget.order.id) ??
        SupabaseService().getOrderById(widget.order.orderNumber);
    _activeOrder = fresh ?? widget.order;
    _currentStatus = _activeOrder.status;
    _totalSeconds = _activeOrder.estimatedDeliveryMinutes * 60;

    if (_currentStatus == OrderStatus.delivered) {
      _remainingSeconds = 0;
    } else if (_currentStatus == OrderStatus.outForDelivery) {
      _remainingSeconds = 4 * 60;
    } else if (_currentStatus == OrderStatus.packing || _currentStatus == OrderStatus.confirmed) {
      _remainingSeconds = 7 * 60;
    } else {
      _remainingSeconds = _activeOrder.estimatedDeliveryMinutes * 60;
    }
    if (_remainingSeconds > _totalSeconds) _totalSeconds = _remainingSeconds;

    // Subscribe to real-time order status notifications from Admin/Store Manager
    SupabaseService().ordersNotifier.addListener(_onOrdersUpdated);

    // Active cross-tab sync ticker (checks shared storage for instant live status propagation)
    _crossTabSyncTimer = Timer.periodic(const Duration(milliseconds: 800), (_) async {
      if (_currentStatus == OrderStatus.delivered) {
        _crossTabSyncTimer?.cancel();
        return;
      }
      final latest = await SupabaseService().getLatestOrderStatus(widget.order.orderNumber) ??
          await SupabaseService().getLatestOrderStatus(widget.order.id);
      final currentOrder = SupabaseService().getOrderById(widget.order.id) ??
          SupabaseService().getOrderById(widget.order.orderNumber);
      if (mounted) {
        if (latest != null && latest != _currentStatus) {
          setState(() {
            _currentStatus = latest;
            _activeOrder = currentOrder ?? _activeOrder.copyWith(status: latest);
            _applyStatusTiming();
          });
        } else if (currentOrder != null && currentOrder.cancellationReason != _activeOrder.cancellationReason) {
          setState(() {
            _activeOrder = currentOrder;
          });
        }
      }
    });

    // Realistic countdown ticker
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0 && _currentStatus != OrderStatus.delivered) {
        if (mounted) {
          setState(() {
            _remainingSeconds--;
          });
        }
      }
    });
  }

  void _applyStatusTiming() {
    if (_currentStatus == OrderStatus.delivered) {
      _remainingSeconds = 0;
      _countdownTimer?.cancel();
      _crossTabSyncTimer?.cancel();
    } else if (_currentStatus == OrderStatus.outForDelivery) {
      if (_remainingSeconds > 300) _remainingSeconds = 240;
    } else if (_currentStatus == OrderStatus.packing) {
      if (_remainingSeconds > 480) _remainingSeconds = 420;
    }
  }

  void _onOrdersUpdated() {
    final updated = SupabaseService().getOrderById(widget.order.id) ??
        SupabaseService().getOrderById(widget.order.orderNumber);
    if (updated != null && mounted) {
      setState(() {
        _activeOrder = updated;
        if (_currentStatus != updated.status) {
          _currentStatus = updated.status;
          _applyStatusTiming();
        }
      });
    }
  }

  @override
  void didUpdateWidget(OrderTrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id ||
        oldWidget.order.status != widget.order.status ||
        oldWidget.order.cancellationReason != widget.order.cancellationReason ||
        oldWidget.order.cancelledBy != widget.order.cancelledBy ||
        oldWidget.order.refundStatus != widget.order.refundStatus ||
        oldWidget.order.paymentStatus != widget.order.paymentStatus) {
      setState(() {
        _activeOrder = widget.order;
        _currentStatus = widget.order.status;
        _applyStatusTiming();
      });
    }
  }

  @override
  void dispose() {
    _crossTabSyncTimer?.cancel();
    SupabaseService().ordersNotifier.removeListener(_onOrdersUpdated);
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------

  bool get _isDelivered => _currentStatus == OrderStatus.delivered;
  bool get _isCancelled => _currentStatus == OrderStatus.cancelled;

  int get _cancellationSecondsLeft {
    if (_currentStatus != OrderStatus.placed && _currentStatus != OrderStatus.confirmed) {
      return 0;
    }
    final elapsed = DateTime.now().difference(_activeOrder.createdAt).inSeconds;
    final left = 60 - elapsed;
    return left > 0 ? left : 0;
  }

  bool get _canCancelOrder => _cancellationSecondsLeft > 0;

  bool get _isCancelledByStore =>
      _activeOrder.cancelledBy == 'store' ||
      _activeOrder.cancellationReason == 'Cancelled by store';

  Future<void> _confirmCancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Order?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          _activeOrder.isCod
              ? 'Are you sure you want to cancel this order? No payment was collected for this order. Items will be restocked immediately.'
              : 'Are you sure you want to cancel this order? Your refund will be initiated and items will be restocked immediately.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep order'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, cancel order'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await SupabaseService().cancelOrder(
        _activeOrder.id,
        reason: 'Cancelled by customer',
        cancelledBy: 'customer',
      );
      if (success && mounted) {
        final isCod = _activeOrder.isCod;
        final refundStatus = isCod ? 'none' : 'initiated';
        final paymentStatus = isCod ? 'pending' : 'refunded';
        setState(() {
          _currentStatus = OrderStatus.cancelled;
          _activeOrder = _activeOrder.copyWith(
            status: OrderStatus.cancelled,
            cancelledBy: 'customer',
            cancellationReason: 'Cancelled by customer',
            cancelledAt: DateTime.now(),
            refundStatus: refundStatus,
            paymentStatus: paymentStatus,
          );
          _remainingSeconds = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCod
                  ? 'Order $_orderNumber cancelled. No payment was collected.'
                  : 'Order $_orderNumber cancelled. Your refund has been initiated.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String get _orderNumber =>
      _activeOrder.orderNumber.startsWith('#') ? _activeOrder.orderNumber : '#${_activeOrder.orderNumber}';

  String get _headline {
    if (_isDelivered) return 'Delivered — enjoy!';
    if (_isCancelled) return 'Order cancelled';
    final mins = (_remainingSeconds / 60).ceil();
    return mins <= 1 ? 'Arriving any moment' : 'Arriving in $mins mins';
  }

  double get _progress {
    if (_isDelivered) return 1;
    if (_isCancelled || _totalSeconds == 0) return 0;
    return (1 - _remainingSeconds / _totalSeconds).clamp(0.05, 0.98);
  }

  int get _stepIndex {
    switch (_currentStatus) {
      case OrderStatus.placed:
        return 0;
      case OrderStatus.confirmed:
        return 1;
      case OrderStatus.packing:
        return 2;
      case OrderStatus.outForDelivery:
        return 3;
      case OrderStatus.delivered:
        return 5;
      case OrderStatus.cancelled:
        return -1;
    }
  }

  List<(String, String)> get _steps {
    final t = _activeOrder.createdAt;
    final eta = t.add(Duration(minutes: _activeOrder.estimatedDeliveryMinutes));
    return [
      ('Order Placed', qbTime(t)),
      ('Order Confirmed', qbTime(t)),
      ('Packing at Dark Store', qbTime(t.add(const Duration(minutes: 2)))),
      ('Out for Delivery', '${qbTime(t.add(const Duration(minutes: 5)))} · Rider on route'),
      ('Delivered', _isDelivered ? 'Delivered' : 'Expected by ${qbTime(eta)}'),
    ];
  }

  void _callRider() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calling delivery partner Ramesh Kumar...')),
    );
  }

  void _showHelp() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Help with $_orderNumber', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final opt in const [
                (Icons.chat_bubble_outline_rounded, 'Chat with support', 'Connecting you to a support agent…'),
                (Icons.inventory_2_outlined, 'Item missing or damaged', 'We have logged your report. Our team will call you shortly.'),
                (Icons.schedule_rounded, 'Order is delayed', 'We have pinged your rider and the store.'),
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: AppColors.primaryLight, child: Icon(opt.$1, color: AppColors.primary)),
                  title: Text(opt.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(opt.$3)));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewBill() {
    OrderCard(order: _activeOrder, onReorder: () => Navigator.pop(context)).showDetails(context);
  }

  @override
  Widget build(BuildContext context) {
    return Responsive.isDesktop(context) ? _buildDesktop() : _buildMobile();
  }

  // ------------------------------- Mobile -----------------------------------

  Widget _buildMobile() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  color: _isCancelled ? AppColors.error : AppColors.primary,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 34),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Back',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
                          ),
                          Expanded(
                            child: Text('Order $_orderNumber',
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                          OutlinedButton(
                            onPressed: _showHelp,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 34),
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                              shape: const StadiumBorder(),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            child: const Text('Help'),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isCancelled
                                  ? (_isCancelledByStore
                                      ? 'Cancelled by Store'
                                      : 'Cancelled by You')
                                  : _currentStatus.displayName,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _headline,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _progressBar(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 210, child: _RouteMap()),
                Transform.translate(
                  offset: const Offset(0, -18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_canCancelOrder) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4F2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFFCDD2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.timer_outlined, color: AppColors.error, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Cancel window closes in ${_cancellationSecondsLeft}s',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFC62828)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _confirmCancelOrder,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ] else if (_isCancelled) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4F2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFFCDD2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.cancel_rounded, color: AppColors.error, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _isCancelledByStore
                                        ? (_activeOrder.isCod
                                            ? 'Order was cancelled by store. No payment was collected for this order. All items returned to store stock.'
                                            : (_activeOrder.refundStatusMessage.isNotEmpty
                                                ? 'Order was cancelled by store. ${_activeOrder.refundStatusMessage} All items returned to store stock.'
                                                : 'Order was cancelled by store. All items returned to store stock.'))
                                        : (_activeOrder.isCod
                                            ? 'You cancelled this order. No payment was collected for this order. All items returned to stock.'
                                            : (_activeOrder.refundStatusMessage.isNotEmpty
                                                ? 'You cancelled this order. ${_activeOrder.refundStatusMessage} All items returned to stock.'
                                                : 'You cancelled this order. All items returned to stock.')),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFC62828)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (!_isCancelled) ...[
                          _riderCard(shadow: true),
                          const SizedBox(height: 12),
                          if (!_isDelivered) ...[_otpCard(), const SizedBox(height: 12)],
                        ],
                        _timelineCard(),
                        const SizedBox(height: 12),
                        _summaryCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressBar({double maxWidth = double.infinity}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: _progress,
          minHeight: 7,
          backgroundColor: Colors.white.withValues(alpha: 0.22),
          valueColor: const AlwaysStoppedAnimation(AppColors.accent),
        ),
      ),
    );
  }

  Widget _riderCard({bool shadow = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: qbCard(shadow: shadow),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: Color(0xFFFFF4D1), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text('RK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF946200))),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ramesh Kumar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Your delivery partner · KA 01 AB 2345', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Material(
            color: AppColors.primaryLight,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Call delivery partner',
              onPressed: _callRider,
              icon: const Icon(Icons.call_outlined, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _otpDigits({double size = 32, Color background = Colors.white}) {
    final otp = _activeOrder.deliveryOtp;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < otp.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Container(
            width: size,
            height: size * 1.25,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
            child: Text(otp[i], style: TextStyle(fontSize: size * 0.58, fontWeight: FontWeight.w800)),
          ),
        ],
      ],
    );
  }

  Widget _otpCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accentBorder),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivery OTP', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Share with the rider only at your door', style: TextStyle(fontSize: 12, color: Color(0xFF5B5133))),
              ],
            ),
          ),
          _otpDigits(),
        ],
      ),
    );
  }

  Widget _timelineCard() {
    final steps = _steps;
    final current = _stepIndex;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: qbCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (_isCancelled) ...[
            QbPill(
              label: _isCancelledByStore
                  ? 'This order was cancelled by the store'
                  : 'This order was cancelled by you',
              icon: Icons.cancel_outlined,
              background: AppColors.errorLight,
              foreground: AppColors.error,
              fontSize: 12,
            ),
            const SizedBox(height: 10),
            Text(
              _isCancelledByStore
                  ? (_activeOrder.isCod
                      ? 'The store had to cancel this order. No payment was collected for this order.'
                      : (_activeOrder.refundStatusMessage.isNotEmpty
                          ? 'The store had to cancel this order. ${_activeOrder.refundStatusMessage}'
                          : 'The store had to cancel this order.'))
                  : (_activeOrder.isCod
                      ? 'You cancelled this order within the cancellation window. No payment was collected for this order.'
                      : (_activeOrder.refundStatusMessage.isNotEmpty
                          ? 'You cancelled this order within the cancellation window. ${_activeOrder.refundStatusMessage}'
                          : 'You cancelled this order within the cancellation window.')),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.45),
            ),
          ]
          else
            for (var i = 0; i < steps.length; i++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Column(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i <= current ? AppColors.primary : Colors.white,
                              border: Border.all(color: i <= current ? AppColors.primary : const Color(0xFFC9D3CD), width: 2),
                            ),
                            alignment: Alignment.center,
                            child: i < current || (i == current && _isDelivered)
                                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                : i == current
                                    ? Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      )
                                    : null,
                          ),
                          if (i < steps.length - 1)
                            Expanded(
                              child: Container(
                                width: 2,
                                constraints: const BoxConstraints(minHeight: 20),
                                color: i < current ? AppColors.primary : const Color(0xFFE2E8E4),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              steps[i].$1,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: i == current ? FontWeight.w800 : FontWeight.w600,
                                color: i > current ? AppColors.textSecondary : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(steps[i].$2, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _summaryCard({bool showHelp = false}) {
    final o = _activeOrder;
    final itemCount = o.items.fold<int>(0, (s, i) => s + i.quantity);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: qbCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 36.0 + (o.items.take(3).length - 1).clamp(0, 2) * 26,
                height: 36,
                child: Stack(
                  children: [
                    for (var i = 0; i < o.items.take(3).length; i++)
                      Positioned(
                        left: i * 26.0,
                        child: Container(
                          width: 36,
                          height: 36,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                          child: QbProductImage(product: o.items[i].product, radius: 8, iconSize: 16),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$itemCount items · ₹${o.grandTotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Text(
                      'Paid via ${o.paymentMethod == 'cod' ? 'Cash on Delivery' : 'UPI'} · ${o.address?.type ?? 'Home'}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: _viewBill, child: const Text('View bill', style: TextStyle(fontWeight: FontWeight.w800))),
            ],
          ),
          if (showHelp) ...[
            if (o.address != null) ...[
              const SizedBox(height: 8),
              Text(o.address!.formattedAddress, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _showHelp,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              child: const Text('Need help with this order?'),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------- Desktop ----------------------------------

  Widget _buildDesktop() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(12),
                        child: const QbLogo(size: 42),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(foregroundColor: AppColors.textBody),
                        child: const Text('Shop'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('My Orders')),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 28, 32, 48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                            decoration: BoxDecoration(
                              color: _isCancelled ? AppColors.error : AppColors.primary,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Order $_orderNumber · ${_isCancelled ? (_isCancelledByStore ? 'Cancelled by Store' : 'Cancelled by You') : _currentStatus.displayName}',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _headline,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 36,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -1,
                                          height: 1.05,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      _progressBar(maxWidth: 520),
                                    ],
                                  ),
                                ),
                                if (!_isDelivered && !_isCancelled)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                                    child: Row(
                                      children: [
                                        const Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Delivery OTP', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                                            Text('Share only at your door',
                                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                        const SizedBox(width: 16),
                                        _otpDigits(size: 34, background: AppColors.accentLight),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Container(
                                  height: 520,
                                  decoration: qbCard(radius: 22),
                                  clipBehavior: Clip.antiAlias,
                                  child: const _RouteMap(large: true),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (_canCancelOrder) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF4F2),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: const Color(0xFFFFCDD2)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.timer_outlined, color: AppColors.error, size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Cancel window closes in ${_cancellationSecondsLeft}s',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFC62828)),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: _confirmCancelOrder,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.error,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                minimumSize: const Size(0, 32),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ] else if (_isCancelled) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF4F2),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: const Color(0xFFFFCDD2)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.cancel_rounded, color: AppColors.error, size: 22),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _isCancelledByStore
                                                    ? (_activeOrder.isCod
                                                        ? 'Order was cancelled by store. No payment was collected for this order. All items returned to store stock.'
                                                        : (_activeOrder.refundStatusMessage.isNotEmpty
                                                            ? 'Order was cancelled by store. ${_activeOrder.refundStatusMessage} All items returned to store stock.'
                                                            : 'Order was cancelled by store. All items returned to store stock.'))
                                                    : (_activeOrder.isCod
                                                        ? 'You cancelled this order. No payment was collected for this order. All items returned to stock.'
                                                        : (_activeOrder.refundStatusMessage.isNotEmpty
                                                            ? 'You cancelled this order. ${_activeOrder.refundStatusMessage} All items returned to stock.'
                                                            : 'You cancelled this order. All items returned to stock.')),
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFC62828)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    if (!_isCancelled) ...[_riderCard(), const SizedBox(height: 16)],
                                    _timelineCard(),
                                    const SizedBox(height: 16),
                                    _summaryCard(showHelp: true),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stylised route map: streets, blocks, dark store, rider and home pins.
class _RouteMap extends StatelessWidget {
  final bool large;
  const _RouteMap({this.large = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final roadX = w * 0.25;
        final roadX2 = w * 0.70;
        final roadY = h * (large ? 0.28 : 0.31);
        final roadY2 = h * 0.72;
        return Container(
          color: const Color(0xFFE9EFEA),
          child: Stack(
            children: [
              Positioned(left: 0, right: 0, top: roadY - 7, height: 14, child: Container(color: Colors.white)),
              Positioned(left: 0, right: 0, top: roadY2 - 5, height: 10, child: Container(color: Colors.white)),
              Positioned(top: 0, bottom: 0, left: roadX - 6, width: 12, child: Container(color: Colors.white)),
              Positioned(top: 0, bottom: 0, left: roadX2 - 7, width: 14, child: Container(color: Colors.white)),
              Positioned(
                left: roadX + 20,
                top: roadY + 20,
                width: roadX2 - roadX - 48,
                height: roadY2 - roadY - 40,
                child: Container(decoration: BoxDecoration(color: const Color(0xFFD8E8DC), borderRadius: BorderRadius.circular(10))),
              ),
              Positioned(
                left: w * 0.04,
                top: roadY + 20,
                width: roadX - w * 0.04 - 20,
                height: roadY2 - roadY - 40,
                child: Container(decoration: BoxDecoration(color: const Color(0xFFDDE5DF), borderRadius: BorderRadius.circular(10))),
              ),
              Positioned.fill(
                child: CustomPaint(painter: _RoutePainter(Offset(roadX, h - 18), Offset(roadX, roadY), Offset(roadX2, roadY), Offset(roadX2, h * 0.12))),
              ),
              Positioned(
                left: roadX - 16,
                top: h - 34,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.storefront_outlined, color: Colors.white, size: 16),
                ),
              ),
              Positioned(
                left: roadX - 20,
                top: (roadY + h) / 2 - 20,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: const Icon(Icons.two_wheeler_rounded, size: 18, color: AppColors.textPrimary),
                ),
              ),
              Positioned(
                left: roadX2 - 18,
                top: h * 0.12 - 36,
                child: const Icon(Icons.location_on, size: 40, color: AppColors.primary, shadows: [
                  Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
                ]),
              ),
              if (large)
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))],
                    ),
                    child: const Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'Rider on the way', style: TextStyle(fontWeight: FontWeight.w800)),
                        TextSpan(text: ' · Ramesh is heading to you'),
                      ]),
                      style: TextStyle(fontSize: 13),
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

class _RoutePainter extends CustomPainter {
  final Offset store;
  final Offset corner1;
  final Offset corner2;
  final Offset home;
  _RoutePainter(this.store, this.corner1, this.corner2, this.home);

  @override
  void paint(Canvas canvas, Size size) {
    final solid = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final mid = Offset(store.dx, (store.dy + corner1.dy) / 2);
    canvas.drawLine(store, mid, solid);
    // Dashed remaining route
    final points = [mid, corner1, corner2, home];
    for (var s = 0; s < points.length - 1; s++) {
      final a = points[s];
      final b = points[s + 1];
      final len = (b - a).distance;
      final dir = (b - a) / len;
      for (double d = 0; d < len; d += 12) {
        final p1 = a + dir * d;
        final p2 = a + dir * (d + 4).clamp(0, len);
        canvas.drawLine(p1, p2, solid);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) =>
      old.store != store || old.corner1 != corner1 || old.corner2 != corner2 || old.home != home;
}
