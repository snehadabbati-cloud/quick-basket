import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/config/delivery_config.dart';
import '../../../models/delivery_partner_model.dart';
import '../../../models/order_model.dart';
import '../../../services/supabase_service.dart';
import '../../../shared_widgets/qb_ui.dart';

/// Modal dialog for assigning an order to an available online delivery partner.
/// Per requirements: Only available online riders (status == 'online' && activeOrderId == null)
/// are eligible for assignment.
class AssignRiderDialog extends StatefulWidget {
  final OrderModel? order;
  final DeliveryPartnerModel? preselectedRider;

  const AssignRiderDialog({
    super.key,
    this.order,
    this.preselectedRider,
  });

  static Future<bool?> show(
    BuildContext context, {
    OrderModel? order,
    DeliveryPartnerModel? rider,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AssignRiderDialog(
        order: order,
        preselectedRider: rider,
      ),
    );
  }

  @override
  State<AssignRiderDialog> createState() => _AssignRiderDialogState();
}

class _AssignRiderDialogState extends State<AssignRiderDialog> {
  List<DeliveryPartnerModel> _riders = [];
  List<OrderModel> _eligibleOrders = [];
  String? _selectedRiderId;
  String? _selectedOrderId;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final riders = await SupabaseService().getDeliveryPartners();
    final allOrders = widget.order != null
        ? [widget.order!]
        : SupabaseService().ordersNotifier.value;

    // Orders eligible for assignment: placed, confirmed, packing (and without assigned rider or stage assigned)
    final eligible = allOrders.where((o) {
      if (o.status == OrderStatus.delivered || o.status == OrderStatus.cancelled) return false;
      return o.riderId == null || o.status != OrderStatus.outForDelivery;
    }).toList();

    // Sort so available online riders appear at the top for instant assignment
    final sortedRiders = List<DeliveryPartnerModel>.from(riders)
      ..sort((a, b) {
        if (a.isAvailableForAssignment && !b.isAvailableForAssignment) return -1;
        if (!a.isAvailableForAssignment && b.isAvailableForAssignment) return 1;
        return a.name.compareTo(b.name);
      });

    if (mounted) {
      setState(() {
        _riders = sortedRiders;
        _eligibleOrders = eligible;
        _selectedRiderId = widget.preselectedRider?.id;
        _selectedOrderId = widget.order?.id;
        _isLoading = false;
      });
    }
  }

  Future<void> _assign() async {
    final orderId = _selectedOrderId ?? widget.order?.id;
    final riderId = _selectedRiderId ?? widget.preselectedRider?.id;

    if (orderId == null || riderId == null) return;

    final rider = _riders.firstWhere((r) => r.id == riderId, orElse: () => _riders.first);

    // Rule check: Only available online riders can be assigned
    if (!rider.isAvailableForAssignment) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot assign: ${rider.name} is ${rider.status.displayName.toLowerCase()}. Only online available riders can take orders.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await SupabaseService().assignRiderToOrder(
        orderId: orderId,
        riderId: riderId,
      );

      if (mounted) {
        if (success) {
          final nav = Navigator.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order assigned to ${rider.name} successfully.'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
          if (nav.canPop()) {
            nav.pop(true);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to assign order. Please try again.'), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetOrder = widget.order ?? _eligibleOrders.cast<OrderModel?>().firstWhere((o) => o?.id == _selectedOrderId, orElse: () => null);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _isLoading
              ? const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.two_wheeler_rounded, color: AppColors.primaryDeep, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assign Delivery Partner',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Dispatch order to an online available rider',
                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Order Info Card
                    if (targetOrder != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  targetOrder.orderNumber,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                                ),
                                QbPill(
                                  label: targetOrder.status.displayName,
                                  background: AppColors.primaryLight,
                                  foreground: AppColors.primaryDeep,
                                  fontSize: 11,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.storefront_outlined, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  'Pickup: ${DeliveryConfig.defaultStoreName} (${DeliveryConfig.defaultStorePincode})',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Drop: ${targetOrder.address?.formattedAddress ?? "Customer Address"}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      // Order picker dropdown
                      const Text('Select Order to Dispatch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedOrderId,
                        decoration: InputDecoration(
                          hintText: 'Choose an active order',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: _eligibleOrders.map((o) {
                          return DropdownMenuItem(
                            value: o.id,
                            child: Text('${o.orderNumber} · ₹${o.grandTotal.toStringAsFixed(0)} · ${o.status.displayName}'),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedOrderId = v),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Rider Selection List
                    const Text('Select Delivery Partner', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text(
                      'Only online & available riders are eligible for assignment',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: _riders.isEmpty
                          ? const Center(child: Text('No delivery partners registered yet.'))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: _riders.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, idx) {
                                final rider = _riders[idx];
                                final isSelected = _selectedRiderId == rider.id;
                                final isEligible = rider.isAvailableForAssignment;

                                return InkWell(
                                  key: ValueKey('rider_select_${rider.id}'),
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: isEligible
                                      ? () => setState(() => _selectedRiderId = rider.id)
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFE8F5E9) : (isEligible ? Colors.white : const Color(0xFFF5F5F5)),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : (isEligible ? AppColors.border : const Color(0xFFEEEEEE)),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Status dot
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: rider.isOnline
                                                ? const Color(0xFF0C8340)
                                                : (rider.isBusy ? const Color(0xFFE65100) : Colors.grey),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Rider details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    rider.name,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 13,
                                                      color: isEligible ? AppColors.textPrimary : Colors.grey,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '⭐ ${rider.rating.toStringAsFixed(1)}',
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFF57C00)),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${rider.phone} · ${rider.vehicleNumber} (${rider.vehicleType.toUpperCase()})',
                                                style: TextStyle(fontSize: 11, color: isEligible ? AppColors.textSecondary : Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Status indicator tag
                                        if (rider.isOnline && rider.activeOrderId == null)
                                          const QbPill(
                                            label: 'Available',
                                            background: Color(0xFFE8F5E9),
                                            foreground: Color(0xFF0C8340),
                                            fontSize: 11,
                                          )
                                        else if (rider.isBusy)
                                          const QbPill(
                                            label: 'On Delivery',
                                            background: Color(0xFFFFF3E0),
                                            foreground: Color(0xFFE65100),
                                            fontSize: 11,
                                          )
                                        else
                                          const QbPill(
                                            label: 'Offline',
                                            background: Color(0xFFEEEEEE),
                                            foreground: Colors.grey,
                                            fontSize: 11,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 18),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: (_selectedRiderId != null && (_selectedOrderId != null || widget.order != null) && !_isSubmitting)
                              ? _assign
                              : null,
                          icon: _isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send_rounded, size: 18),
                          label: const Text('Confirm Assignment', style: TextStyle(fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
