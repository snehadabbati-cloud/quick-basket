import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/config/delivery_config.dart';
import '../../../models/delivery_partner_model.dart';
import '../../../models/order_model.dart';
import '../../../services/supabase_service.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../widgets/doorstep_otp_dialog.dart';
import 'rider_login_screen.dart';

/// Full-featured Rider Partner Dashboard & Delivery Execution Interface.
/// Implements:
/// - Live duty toggle (Online / Offline)
/// - Assigned delivery request management (Accept / Reject)
/// - Step-by-step delivery pipeline (Reached Store -> Picked Up -> Out for Delivery)
/// - Dark store pickup verification & customer delivery directions
/// - Confidential Doorstep OTP Verification modal (never exposes OTP to rider)
/// - Daily earnings summary (₹40 / completed delivery)
class RiderDashboardScreen extends StatefulWidget {
  final DeliveryPartnerModel? rider;

  const RiderDashboardScreen({super.key, this.rider});

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  DeliveryPartnerModel? _rider;
  List<OrderModel> _assignedOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initRider();
    SupabaseService().ordersNotifier.addListener(_onDataChanged);
    SupabaseService().ridersNotifier.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    SupabaseService().ordersNotifier.removeListener(_onDataChanged);
    SupabaseService().ridersNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      _refreshData(silent: true);
    }
  }

  Future<void> _initRider() async {
    if (widget.rider != null) {
      _rider = widget.rider;
    } else {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('active_rider_id');
      final allRiders = await SupabaseService().getDeliveryPartners();
      if (allRiders.isNotEmpty) {
        _rider = allRiders.firstWhere(
          (r) => r.id == savedId,
          orElse: () => allRiders.first,
        );
      }
    }
    await _refreshData(silent: true);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    if (_rider == null) return;

    final allRiders = await SupabaseService().getDeliveryPartners();
    final freshRider = allRiders.cast<DeliveryPartnerModel?>().firstWhere(
      (r) => r?.id == _rider!.id,
      orElse: () => _rider,
    );

    final allOrders = await SupabaseService().getAllStoreOrders();
    final myOrders = allOrders.where((o) => o.riderId == _rider!.id).toList();

    if (mounted) {
      setState(() {
        _rider = freshRider;
        _assignedOrders = myOrders;
        if (!silent) _isLoading = false;
      });
    }
  }

  OrderModel? get _activeOrder {
    try {
      return _assignedOrders.firstWhere(
        (o) => o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled,
      );
    } catch (_) {
      return null;
    }
  }

  List<OrderModel> get _completedOrders {
    return _assignedOrders.where((o) => o.status == OrderStatus.delivered).toList();
  }

  double get _todayEarnings => _completedOrders.length * DeliveryConfig.defaultPerDeliveryEarning;

  Future<void> _toggleDuty(bool goOnline) async {
    if (_rider == null) return;
    if (_rider!.isBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot go offline while on an active delivery.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final newStatus = goOnline ? DeliveryPartnerStatus.online : DeliveryPartnerStatus.offline;
    final success = await SupabaseService().updateDeliveryPartnerStatus(_rider!.id, newStatus);

    if (mounted) {
      if (success) {
        setState(() => _rider = _rider!.copyWith(status: newStatus));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(goOnline ? 'You are now Online. Ready for orders!' : 'You are now Offline.'),
            backgroundColor: goOnline ? const Color(0xFF0C8340) : Colors.grey.shade800,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _acceptOrder(OrderModel order) async {
    await _advanceStage(order, 'accepted');
  }

  Future<void> _rejectOrder(OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Delivery Request?'),
        content: const Text('The order will be returned to the dark store pool for another partner.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted && _rider != null) {
      final success = await SupabaseService().rejectOrderAssignment(order.id, _rider!.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order declined.'), backgroundColor: Colors.grey),
        );
        _refreshData(silent: true);
      }
    }
  }

  Future<void> _advanceStage(OrderModel order, String nextStage) async {
    final success = await SupabaseService().updateRiderDeliveryStage(order.id, nextStage);
    if (success && mounted) {
      _refreshData(silent: true);
    }
  }

  Future<void> _verifyDoorstepOtp(OrderModel order) async {
    if (_rider == null) return;
    final verified = await DoorstepOtpDialog.show(
      context,
      order: order,
      riderId: _rider!.id,
    );

    if (verified == true && mounted) {
      _refreshData(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _rider == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isOnline = _rider!.isOnline;
    final isBusy = _rider!.isBusy;
    final active = _activeOrder;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isOnline ? const Color(0xFFE8F5E9) : const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.two_wheeler_rounded,
                color: isOnline ? const Color(0xFF0C8340) : Colors.grey,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _rider!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                  ),
                  Text(
                    '${_rider!.vehicleNumber} · ⭐ ${_rider!.rating.toStringAsFixed(1)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.switch_account_outlined, color: AppColors.textSecondary),
            tooltip: 'Switch Rider Profile',
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const RiderLoginScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.home_outlined, color: AppColors.textSecondary),
            tooltip: 'Customer App',
            onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshData(silent: false),
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Online / Offline Duty Switcher Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: isOnline ? const Color(0xFFE8F5E9) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isOnline ? const Color(0xFFA5D6A7) : AppColors.border, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline ? const Color(0xFF0C8340) : (isBusy ? const Color(0xFFE65100) : Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isBusy ? 'On Active Delivery' : (isOnline ? 'You are Online' : 'You are Offline'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isOnline ? const Color(0xFF1B5E20) : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isBusy
                                ? 'Complete doorstep delivery to take next order'
                                : (isOnline ? 'Ready to receive dark store order dispatches' : 'Go online to receive delivery requests'),
                            style: TextStyle(
                              fontSize: 12,
                              color: isOnline ? const Color(0xFF2E7D32) : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      key: const ValueKey('rider_duty_switch'),
                      value: isOnline || isBusy,
                      activeColor: const Color(0xFF0C8340),
                      activeTrackColor: const Color(0xFFA5D6A7),
                      onChanged: isBusy ? null : (val) => _toggleDuty(val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Daily Earnings Summary Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('TODAY\'S EARNINGS', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                        Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF38BDF8), size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹${_todayEarnings.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(@ ₹${DeliveryConfig.defaultPerDeliveryEarning.toStringAsFixed(0)}/order)',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _earningsPill(Icons.check_circle_outline, '${_completedOrders.length} Delivered', const Color(0xFF4ADE80)),
                        _earningsPill(Icons.electric_moped_outlined, isBusy ? '1 In Progress' : '0 In Progress', const Color(0xFFFBBF24)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Active Delivery Section
              const Text(
                'Active Delivery',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),

              if (active == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                        child: const Icon(Icons.two_wheeler_outlined, size: 36, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No active deliveries right now',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOnline ? 'You will be notified when an order is assigned by dark store.' : 'Turn your status Online to start receiving delivery dispatches.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                _buildActiveOrderCard(active),

              const SizedBox(height: 24),

              // Completed Deliveries Section
              if (_completedOrders.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Completed Deliveries', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text('${_completedOrders.length} orders', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 10),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _completedOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final o = _completedOrders[idx];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, color: Color(0xFF0C8340), size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(o.orderNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(
                                  o.address?.formattedAddress ?? 'Delivered to Doorstep',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+₹${DeliveryConfig.defaultPerDeliveryEarning.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0C8340)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _earningsPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildActiveOrderCard(OrderModel order) {
    final stage = order.deliveryStage ?? 'assigned';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA5D6A7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0C8340).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      '${order.items.length} items · ₹${order.grandTotal.toStringAsFixed(0)} · ${order.paymentMethod.toUpperCase()}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              QbPill(
                label: _stageDisplayName(stage),
                background: const Color(0xFFE8F5E9),
                foreground: const Color(0xFF0C8340),
                fontSize: 11,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stepper Tracker
          _buildStageStepper(stage),
          const SizedBox(height: 16),

          // Store Pickup Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF0C8340)),
                    SizedBox(width: 8),
                    Text('PICKUP FROM DARK STORE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0C8340))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${DeliveryConfig.defaultStoreName} (${DeliveryConfig.defaultStorePincode})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Customer Drop Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFE65100)),
                    SizedBox(width: 8),
                    Text('DELIVER TO CUSTOMER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFE65100))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  order.address?.formattedAddress ?? 'Customer Doorstep Address',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_city_outlined, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${order.address?.type ?? "Home"} · ${order.address?.pincode ?? DeliveryConfig.defaultStorePincode}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (order.deliveryInstructions != null && order.deliveryInstructions!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Note: ${order.deliveryInstructions}', style: const TextStyle(fontSize: 11, color: Color(0xFF795548))),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Contextual Action Buttons based on Stage
          _buildStageActions(order, stage),
        ],
      ),
    );
  }

  Widget _buildStageStepper(String currentStage) {
    final stages = ['assigned', 'accepted', 'reached_store', 'picked_up', 'out_for_delivery'];
    final labels = ['Assigned', 'Accepted', 'At Store', 'Picked Up', 'Delivering'];
    final currIdx = stages.indexOf(currentStage);

    return Row(
      children: [
        for (int i = 0; i < stages.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= currIdx ? const Color(0xFF0C8340) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: i == currIdx ? FontWeight.w800 : FontWeight.w600,
                    color: i <= currIdx ? const Color(0xFF0C8340) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          if (i < stages.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }

  String _stageDisplayName(String stage) {
    switch (stage) {
      case 'assigned':
        return 'New Request';
      case 'accepted':
        return 'Heading to Store';
      case 'reached_store':
        return 'At Dark Store';
      case 'picked_up':
        return 'Picked Up';
      case 'out_for_delivery':
        return 'Out for Delivery';
      default:
        return stage.toUpperCase();
    }
  }

  Widget _buildStageActions(OrderModel order, String stage) {
    switch (stage) {
      case 'assigned':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _rejectOrder(order),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => _acceptOrder(order),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Accept Delivery', style: TextStyle(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C8340),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        );

      case 'accepted':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _advanceStage(order, 'reached_store'),
            icon: const Icon(Icons.storefront_rounded, size: 18),
            label: const Text('Reached Dark Store', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0C8340),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );

      case 'reached_store':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _advanceStage(order, 'picked_up'),
            icon: const Icon(Icons.inventory_2_rounded, size: 18),
            label: const Text('Confirm Items & Pick Up', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0C8340),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );

      case 'picked_up':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _advanceStage(order, 'out_for_delivery'),
            icon: const Icon(Icons.moped_rounded, size: 18),
            label: const Text('Start Route (Out for Delivery)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );

      case 'out_for_delivery':
      default:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security_rounded, size: 16, color: Color(0xFF0C8340)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Doorstep Verification: Ask customer for their 4-digit Delivery OTP.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1B5E20)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const ValueKey('verify_otp_button'),
                onPressed: () => _verifyDoorstepOtp(order),
                icon: const Icon(Icons.verified_user_rounded, size: 20),
                label: const Text('Verify Doorstep OTP & Complete', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C8340),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        );
    }
  }
}
