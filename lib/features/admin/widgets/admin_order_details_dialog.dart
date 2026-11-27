import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../services/supabase_service.dart';
import 'admin_orders_logic.dart';
import 'assign_rider_dialog.dart';

/// Professional Dark Store Order Fulfillment & Fast-Picking Dialog
class AdminOrderDetailsDialog extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onOrderUpdated;

  const AdminOrderDetailsDialog({
    super.key,
    required this.order,
    required this.onOrderUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required OrderModel order,
    required VoidCallback onOrderUpdated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AdminOrderDetailsDialog(
        order: order,
        onOrderUpdated: onOrderUpdated,
      ),
    );
  }

  @override
  State<AdminOrderDetailsDialog> createState() => _AdminOrderDetailsDialogState();
}

class _AdminOrderDetailsDialogState extends State<AdminOrderDetailsDialog> {
  late Set<String> _pickedItemIds;
  bool _isUpdating = false;
  late OrderModel _order;

  @override
  void initState() {
    super.initState();
    final fresh = SupabaseService().getOrderById(widget.order.id) ??
        SupabaseService().getOrderById(widget.order.orderNumber);
    _order = fresh ?? widget.order;
    _pickedItemIds = {};
    _syncPicked();
    SupabaseService().ordersNotifier.addListener(_onOrdersNotifierChanged);
  }

  void _syncPicked() {
    if (_order.status == OrderStatus.packing ||
        _order.status == OrderStatus.outForDelivery ||
        _order.status == OrderStatus.delivered) {
      for (final item in _order.items) {
        _pickedItemIds.add(item.variant.id);
      }
    }
  }

  void _onOrdersNotifierChanged() {
    final fresh = SupabaseService().getOrderById(_order.id) ??
        SupabaseService().getOrderById(_order.orderNumber);
    if (fresh != null && mounted) {
      setState(() {
        _order = fresh;
        _syncPicked();
      });
    }
  }

  @override
  void dispose() {
    SupabaseService().ordersNotifier.removeListener(_onOrdersNotifierChanged);
    super.dispose();
  }

  void _togglePickAll() {
    setState(() {
      if (_pickedItemIds.length == _order.items.length) {
        _pickedItemIds.clear();
      } else {
        for (final item in _order.items) {
          _pickedItemIds.add(item.variant.id);
        }
      }
    });
  }

  Future<void> _rejectOrder() async {
    setState(() => _isUpdating = true);
    final isCod = _order.isCod;
    final refundStatus = isCod ? 'none' : 'initiated';
    final paymentStatus = isCod ? 'pending' : 'refunded';
    await SupabaseService().updateOrderStatus(
      _order.id,
      OrderStatus.cancelled,
      cancelledBy: 'store',
      cancellationReason: 'Cancelled by store',
      refundStatus: refundStatus,
      paymentStatus: paymentStatus,
    );
    await SupabaseService().restoreOrderStock(_order);
    final fresh = SupabaseService().getOrderById(_order.id) ??
        SupabaseService().getOrderById(_order.orderNumber) ??
        _order.copyWith(
          status: OrderStatus.cancelled,
          cancelledBy: 'store',
          cancellationReason: 'Cancelled by store',
          refundStatus: refundStatus,
          paymentStatus: paymentStatus,
        );

    if (mounted) {
      setState(() {
        _order = fresh;
        _isUpdating = false;
        _syncPicked();
      });
      widget.onOrderUpdated();
    }
  }

  Future<void> _openAssignRider() async {
    final assigned = await AssignRiderDialog.show(context, order: _order);
    if (assigned == true) _refreshFromService();
  }

  Future<void> _unassignRider() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unassign rider?'),
        content: Text('${_order.riderName ?? 'The rider'} will be freed and the order goes back to Picking & packing so you can assign someone else.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unassign')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _isUpdating = true);
    await SupabaseService().unassignRider(_order.id);
    _refreshFromService();
  }

  void _refreshFromService() {
    final fresh = SupabaseService().getOrderById(_order.id) ?? SupabaseService().getOrderById(_order.orderNumber);
    if (!mounted) return;
    setState(() {
      if (fresh != null) _order = fresh;
      _isUpdating = false;
    });
    widget.onOrderUpdated();
  }

  Future<void> _updateStatus(OrderStatus newStatus) async {
    setState(() => _isUpdating = true);
    await SupabaseService().updateOrderStatus(_order.id, newStatus);
    await SupabaseService().updateOrderStatus(_order.orderNumber, newStatus);
    final fresh = SupabaseService().getOrderById(_order.id) ??
        SupabaseService().getOrderById(_order.orderNumber) ??
        _order.copyWith(status: newStatus);

    if (mounted) {
      setState(() {
        _order = fresh;
        _isUpdating = false;
        _syncPicked();
      });
      widget.onOrderUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = _order.items.length;
    final pickedCount = _pickedItemIds.length;
    final progress = totalItems > 0 ? (pickedCount / totalItems) : 1.0;
    final isDelivered = _order.status == OrderStatus.delivered;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Container(
          width: 640,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Dialog Header
              _buildHeader(),

              const Divider(height: 1, color: Color(0xFFE5E7EB)),

              // 2. Scrollable Body
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Delivery Destination & Customer Info
                    _buildCustomerDestinationCard(),

                    const SizedBox(height: 12),

                    // Delivery Partner Assignment Card
                    _buildDeliveryPartnerCard(),

                    const SizedBox(height: 16),

                    // Store Item Picking Checklist Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF064E26)),
                            const SizedBox(width: 8),
                            const Text(
                              'Store Picking Checklist',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: progress == 1.0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$pickedCount/$totalItems Picked',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: progress == 1.0 ? const Color(0xFF0C8340) : const Color(0xFFE65100),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!isDelivered)
                          TextButton(
                            onPressed: _togglePickAll,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              pickedCount == totalItems ? 'Uncheck All' : 'Pick All (1-Click)',
                              style: const TextStyle(
                                color: Color(0xFF0C8340),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFF3F4F6),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress == 1.0 ? const Color(0xFF0C8340) : const Color(0xFFE65100),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Picking Items List
                    ..._order.items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final isPicked = _pickedItemIds.contains(item.variant.id);
                      final aisle = 'Aisle ${(idx % 4) + 1} • Shelf ${String.fromCharCode(65 + (idx % 3))}';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isPicked ? const Color(0xFFF0FDF4) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isPicked ? const Color(0xFF86EFAC) : const Color(0xFFE5E7EB),
                            width: isPicked ? 1.5 : 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: isDelivered
                              ? null
                              : () {
                                  setState(() {
                                    if (isPicked) {
                                      _pickedItemIds.remove(item.variant.id);
                                    } else {
                                      _pickedItemIds.add(item.variant.id);
                                    }
                                  });
                                },
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    item.product.imageUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.grey.shade100,
                                      child: const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Product & Location Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          decoration: isPicked ? TextDecoration.lineThrough : null,
                                          color: isPicked ? Colors.grey.shade600 : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Text(
                                            '${item.variant.unit}  •  Qty: ${item.quantity}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              aisle,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1D4ED8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Price & Checkbox
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${item.totalPrice.toStringAsFixed(0)}',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Icon(
                                      isPicked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                      color: isPicked ? const Color(0xFF0C8340) : Colors.grey.shade400,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 8),

                    // Bill Summary Row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Order Bill',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary),
                          ),
                          Text(
                            '₹${_order.grandTotal.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0C8340)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE5E7EB)),

              // 3. Bottom Action Bar
              _buildBottomActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF064E26).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF064E26), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _order.orderNumber,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(_order.status),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Payment: ${_order.paymentMethod.toUpperCase()}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _order.paymentStatus == 'completed' ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _order.paymentStatus.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: _order.paymentStatus == 'completed' ? const Color(0xFF0C8340) : const Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.grey),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerDestinationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF0C8340)),
              SizedBox(width: 6),
              Text(
                'Customer Delivery Destination',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _order.address?.formattedAddress ?? 'Flat 402, Sunshine Apartments, Bengaluru - 560001',
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.3),
          ),
          if (_order.deliveryInstructions != null && _order.deliveryInstructions!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text(
                '⚠️ Delivery Note: ${_order.deliveryInstructions}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryPartnerCard() {
    final hasRider = _order.riderId != null || (_order.riderName != null && _order.riderName!.isNotEmpty);
    final isDelivered = _order.status == OrderStatus.delivered;
    final isCancelled = _order.status == OrderStatus.cancelled;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasRider ? const Color(0xFFF1F8E9) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hasRider ? const Color(0xFFA5D6A7) : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.two_wheeler_rounded,
                      size: 18,
                      color: hasRider ? const Color(0xFF2E7D32) : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        hasRider ? 'Assigned Delivery Partner' : 'Delivery Partner Assignment',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isDelivered && !isCancelled && _order.status != OrderStatus.placed)
                TextButton.icon(
                  onPressed: _isUpdating ? null : _openAssignRider,
                  icon: Icon(hasRider ? Icons.swap_horiz_rounded : Icons.person_add_rounded, size: 14),
                  label: Text(hasRider ? 'Reassign' : 'Assign Rider', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  style: TextButton.styleFrom(
                    foregroundColor: hasRider ? const Color(0xFF2E7D32) : AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasRider) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFFC8E6C9),
                  child: Text(
                    _order.riderName?.isNotEmpty == true ? _order.riderName![0].toUpperCase() : 'R',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1B5E20)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _order.riderName ?? 'Delivery Partner',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_order.riderPhone ?? ""} · ${_order.riderVehicleNumber ?? ""}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: Text(
                    (_order.deliveryStage ?? 'assigned').replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              OrderFlow.riderProgress(_order),
              key: const ValueKey('admin_rider_progress'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: OrderFlow.hasIssue(_order) ? AppColors.error : const Color(0xFF2E7D32),
              ),
            ),
            if (!isDelivered && !isCancelled && _order.status != OrderStatus.outForDelivery) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _isUpdating ? null : _unassignRider,
                icon: const Icon(Icons.person_remove_alt_1_rounded, size: 14),
                label: const Text('Unassign rider', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ] else ...[
            Text(
              _order.status == OrderStatus.placed
                  ? 'Accept the order first, then assign an online rider.'
                  : "No delivery partner assigned yet. Assign an online rider — they pick it up from the store and deliver it with the customer's OTP.",
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final status = _order.status;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (status == OrderStatus.placed) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _isUpdating ? null : _rejectOrder,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Reject Order', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isUpdating ? null : () => _updateStatus(OrderStatus.confirmed),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C8340),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isUpdating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Accept Order', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ] else if (status == OrderStatus.confirmed) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isUpdating ? null : () => _updateStatus(OrderStatus.packing),
                icon: const Icon(Icons.inventory_2_rounded, size: 18),
                label: const Text('Start Picking & Packing', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C8340),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ] else if (status == OrderStatus.packing || status == OrderStatus.partnerAssigned || status == OrderStatus.outForDelivery) ...[
            Expanded(
              child: OrderFlow.hasRider(_order) && !OrderFlow.hasIssue(_order)
                  ? Container(
                      key: const ValueKey('admin_rider_driven_status'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F8E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.two_wheeler_rounded, color: Color(0xFF2E7D32), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              status == OrderStatus.outForDelivery
                                  ? "Out for delivery — the rider completes it with the customer's OTP"
                                  : 'Rider assigned — the order moves to Out for delivery when the rider picks it up',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1B5E20), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _isUpdating ? null : _openAssignRider,
                      icon: Icon(OrderFlow.hasIssue(_order) ? Icons.swap_horiz_rounded : Icons.person_add_rounded, size: 20),
                      label: Text(OrderFlow.hasIssue(_order) ? 'Rider reported an issue — Reassign rider' : 'Assign Rider',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OrderFlow.hasIssue(_order) ? AppColors.error : const Color(0xFFE65100),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
            ),
          ] else if (status == OrderStatus.delivered) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF0C8340), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Order Fulfilled & Handed Over (OTP Verified)',
                      style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF064E26), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (status == OrderStatus.cancelled) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cancel_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _order.cancelledBy == 'store' || _order.cancellationReason == 'Cancelled by store'
                            ? 'Cancelled by Store • Items Restocked'
                            : (_order.isCod
                                ? 'Cancelled by Customer • No Payment Collected • Items Restocked'
                                : 'Cancelled by Customer • ${_order.refundStatus == 'processed' ? "Refund Processed" : "Refund Initiated"} • Items Restocked'),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.error, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Order ${status.displayName}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.error),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case OrderStatus.placed:
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        icon = Icons.notifications_active_rounded;
        break;
      case OrderStatus.confirmed:
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF57F17);
        icon = Icons.thumb_up_rounded;
        break;
      case OrderStatus.packing:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        icon = Icons.inventory_2_rounded;
        break;
      case OrderStatus.partnerAssigned:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        icon = Icons.delivery_dining_rounded;
        break;
      case OrderStatus.outForDelivery:
        bg = const Color(0xFFE1F5FE);
        fg = const Color(0xFF0288D1);
        icon = Icons.delivery_dining_rounded;
        break;
      case OrderStatus.delivered:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF0C8340);
        icon = Icons.check_circle_rounded;
        break;
      case OrderStatus.cancelled:
        bg = const Color(0xFFFFEBEE);
        fg = AppColors.error;
        icon = Icons.cancel_rounded;
        final isStore = _order.cancelledBy == 'store' || _order.cancellationReason == 'Cancelled by store';
        final label = isStore ? 'Cancelled (Store)' : 'Cancelled (Customer)';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
              ),
            ],
          ),
        );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
          ),
        ],
      ),
    );
  }
}
