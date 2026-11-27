import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/delivery_partner_model.dart';
import '../../../models/order_model.dart';
import '../../../services/supabase_service.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../widgets/admin_ui.dart';
import '../widgets/add_delivery_partner_dialog.dart';
import '../widgets/assign_rider_dialog.dart';

/// Full-featured Admin Delivery Partner Management Page.
/// Implements:
/// - Delivery partner roster with status, ratings, vehicle info and total deliveries
/// - Real-time Online / Offline status toggles
/// - Add Rider modal integration
/// - Order assignment to available online riders
class AdminDeliveryPartnersPage extends StatefulWidget {
  final List<OrderModel> orders;
  final ValueChanged<OrderModel>? onOpenOrder;

  const AdminDeliveryPartnersPage({
    super.key,
    required this.orders,
    this.onOpenOrder,
  });

  @override
  State<AdminDeliveryPartnersPage> createState() => _AdminDeliveryPartnersPageState();
}

class _AdminDeliveryPartnersPageState extends State<AdminDeliveryPartnersPage> {
  List<DeliveryPartnerModel> _riders = [];
  bool _isLoading = true;
  String _search = '';
  String _statusFilter = 'all'; // 'all', 'online', 'busy', 'offline'

  @override
  void initState() {
    super.initState();
    _loadRiders();
    SupabaseService().ridersNotifier.addListener(_onRidersChanged);
  }

  @override
  void dispose() {
    SupabaseService().ridersNotifier.removeListener(_onRidersChanged);
    super.dispose();
  }

  void _onRidersChanged() {
    if (mounted) {
      _loadRiders(silent: true);
    }
  }

  Future<void> _loadRiders({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final list = await SupabaseService().getDeliveryPartners();
    if (mounted) {
      setState(() {
        _riders = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleRiderStatus(DeliveryPartnerModel rider, bool goOnline) async {
    if (rider.isBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${rider.name} is currently on an active delivery. Status cannot be toggled until the delivery completes.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final newStatus = goOnline ? DeliveryPartnerStatus.online : DeliveryPartnerStatus.offline;
    final success = await SupabaseService().updateDeliveryPartnerStatus(rider.id, newStatus);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${rider.name} is now ${newStatus.displayName}.'),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  List<DeliveryPartnerModel> get _filteredRiders {
    return _riders.where((r) {
      // Status filter
      if (_statusFilter == 'online' && !r.isOnline) return false;
      if (_statusFilter == 'busy' && !r.isBusy) return false;
      if (_statusFilter == 'offline' && !r.isOffline) return false;

      // Search query filter
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final matchName = r.name.toLowerCase().contains(q);
        final matchPhone = r.phone.toLowerCase().contains(q);
        final matchVehicle = r.vehicleNumber.toLowerCase().contains(q);
        return matchName || matchPhone || matchVehicle;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final total = _riders.length;
    final onlineCount = _riders.where((r) => r.isOnline).length;
    final busyCount = _riders.where((r) => r.isBusy).length;
    final offlineCount = _riders.where((r) => r.isOffline).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delivery Partners',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage rider fleet, live availability, and doorstep delivery assignments',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.9)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final created = await AddDeliveryPartnerDialog.show(context);
                    if (created != null) _loadRiders(silent: true);
                  },
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Add Delivery Partner', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Summary Metric Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                final cards = [
                  _metricCard('Total Fleet', '$total', Icons.two_wheeler_rounded, const Color(0xFF1976D2), const Color(0xFFE3F2FD)),
                  _metricCard('Available (Online)', '$onlineCount', Icons.check_circle_outline_rounded, const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
                  _metricCard('On Delivery (Busy)', '$busyCount', Icons.electric_moped_rounded, const Color(0xFFEF6C00), const Color(0xFFFFF3E0)),
                  _metricCard('Offline', '$offlineCount', Icons.nightlight_round, const Color(0xFF616161), const Color(0xFFF5F5F5)),
                ];

                if (isWide) {
                  return Row(
                    children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
                  );
                } else {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: cards.map((c) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: c)).toList(),
                  );
                }
              },
            ),
            const SizedBox(height: 24),

            // Filter Bar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search rider by name, phone, or vehicle...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _filterChip('all', 'All ($total)'),
                        const SizedBox(width: 6),
                        _filterChip('online', 'Available ($onlineCount)'),
                        const SizedBox(width: 6),
                        _filterChip('busy', 'Busy ($busyCount)'),
                        const SizedBox(width: 6),
                        _filterChip('offline', 'Offline ($offlineCount)'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Rider List
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_filteredRiders.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.two_wheeler_outlined, size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    const Text('No delivery partners found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      _search.isNotEmpty ? 'Try adjusting your search criteria' : 'Register your first rider to begin assignments',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredRiders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, idx) => _buildRiderCard(_filteredRiders[idx]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final active = _statusFilter == key;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _statusFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryDeep : const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildRiderCard(DeliveryPartnerModel rider) {
    final isOnline = rider.isOnline;
    final isBusy = rider.isBusy;
    final isOffline = rider.isOffline;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBusy
              ? const Color(0xFFFFCC80)
              : (isOnline ? const Color(0xFFA5D6A7) : AppColors.border),
          width: isBusy || isOnline ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with status indicator dot
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isOnline
                    ? const Color(0xFFE8F5E9)
                    : (isBusy ? const Color(0xFFFFF3E0) : const Color(0xFFEEEEEE)),
                child: Text(
                  rider.name.isNotEmpty ? rider.name[0].toUpperCase() : 'R',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isOnline
                        ? const Color(0xFF2E7D32)
                        : (isBusy ? const Color(0xFFEF6C00) : Colors.grey),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isOnline
                        ? const Color(0xFF2E7D32)
                        : (isBusy ? const Color(0xFFEF6C00) : Colors.grey),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Rider Info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rider.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFA000)),
                          const SizedBox(width: 2),
                          Text(
                            rider.rating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB78103)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_outlined, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(rider.phone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.two_wheeler_outlined, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${rider.vehicleNumber} (${rider.vehicleType.toUpperCase()})',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Total Deliveries
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Deliveries', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${rider.totalDeliveries} completed',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),

          // Active Order (if on delivery)
          if (rider.activeOrderId != null) ...[
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () {
                  final activeOrder = widget.orders.cast<OrderModel?>().firstWhere(
                    (o) => o?.id == rider.activeOrderId || o?.orderNumber == rider.activeOrderId,
                    orElse: () => null,
                  );
                  if (activeOrder != null && widget.onOpenOrder != null) {
                    widget.onOpenOrder!(activeOrder);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFCC80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.moped_rounded, size: 14, color: Color(0xFFE65100)),
                      const SizedBox(width: 6),
                      Text(
                        'Order #${rider.activeOrderId!.length > 8 ? rider.activeOrderId!.substring(0, 8) : rider.activeOrderId}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFE65100)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else
            const Spacer(flex: 2),

          // Online / Offline Switch
          Row(
            children: [
              Text(
                isBusy ? 'Busy' : (isOnline ? 'Online' : 'Offline'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isOnline
                      ? const Color(0xFF2E7D32)
                      : (isBusy ? const Color(0xFFEF6C00) : Colors.grey),
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                key: ValueKey('switch_${rider.id}'),
                value: isOnline || isBusy,
                activeColor: const Color(0xFF2E7D32),
                activeTrackColor: const Color(0xFFA5D6A7),
                onChanged: isBusy ? null : (val) => _toggleRiderStatus(rider, val),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Assign Order Action Button
          ElevatedButton.icon(
            onPressed: rider.isAvailableForAssignment
                ? () async {
                    final assigned = await AssignRiderDialog.show(context, rider: rider);
                    if (assigned == true) _loadRiders(silent: true);
                  }
                : null,
            icon: const Icon(Icons.send_rounded, size: 15),
            label: const Text('Assign Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE0E0E0),
              disabledForegroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
