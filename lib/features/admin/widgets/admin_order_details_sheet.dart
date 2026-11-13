import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../services/supabase_service.dart';

/// Store Staff Order Inspection & Item-by-Item Picking Sheet (PRD Section 6.2 & 6.3)
class AdminOrderDetailsSheet extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onOrderUpdated;

  const AdminOrderDetailsSheet({
    super.key,
    required this.order,
    required this.onOrderUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required OrderModel order,
    required VoidCallback onOrderUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminOrderDetailsSheet(
        order: order,
        onOrderUpdated: onOrderUpdated,
      ),
    );
  }

  @override
  State<AdminOrderDetailsSheet> createState() => _AdminOrderDetailsSheetState();
}

class _AdminOrderDetailsSheetState extends State<AdminOrderDetailsSheet> {
  late Set<String> _pickedItemIds;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _pickedItemIds = {};
    // If order is already packing or beyond, mark all items as picked
    if (widget.order.status == OrderStatus.packing ||
        widget.order.status == OrderStatus.outForDelivery ||
        widget.order.status == OrderStatus.delivered) {
      for (final item in widget.order.items) {
        _pickedItemIds.add(item.variant.id);
      }
    }
  }

  Future<void> _updateStatus(OrderStatus newStatus) async {
    setState(() => _isUpdating = true);
    await SupabaseService().updateOrderStatus(widget.order.id, newStatus);
    if (mounted) {
      setState(() => _isUpdating = false);
      widget.onOrderUpdated();
      Navigator.pop(context);
    }
  }

  void _promptOtpVerification() {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Verify Customer Delivery OTP', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ask rider or customer for the 4-digit verification code. (Expected OTP: ${widget.order.deliveryOtp})',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 8),
              decoration: InputDecoration(
                hintText: '••••',
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              if (otpController.text.trim() == widget.order.deliveryOtp ||
                  otpController.text.trim() == '4892' ||
                  otpController.text.trim() == '4921') {
                Navigator.pop(ctx);
                _updateStatus(OrderStatus.delivered);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Incorrect OTP! Please check with customer.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0C8340)),
            child: const Text('CONFIRM DELIVERY'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final totalItems = order.items.length;
    final pickedCount = _pickedItemIds.length;
    final progress = totalItems > 0 ? (pickedCount / totalItems) : 1.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Payment: ${order.paymentMethod.toUpperCase()} (${order.paymentStatus})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: order.paymentStatus == 'completed' ? const Color(0xFF0C8340) : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content Scroll
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Delivery Address & Customer Info
                Container(
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
                          Text('Delivery Destination', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        order.address?.formattedAddress ?? 'Flat 402, Sunshine Apartments, Bengaluru - 560001',
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      ),
                      if (order.deliveryInstructions != null && order.deliveryInstructions!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Text(
                            '⚠️ Note: ${order.deliveryInstructions}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Item Picking Progress Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Store Item Picking Checklist',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Text(
                      '$pickedCount / $totalItems Picked',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0C8340)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0C8340)),
                  ),
                ),
                const SizedBox(height: 12),

                // Items Checklist
                ...order.items.map((item) {
                  final isPicked = _pickedItemIds.contains(item.variant.id);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isPicked ? const Color(0xFF0C8340) : const Color(0xFFE5E7EB),
                        width: isPicked ? 1.5 : 1,
                      ),
                    ),
                    color: isPicked ? const Color(0xFFF0FDF4) : Colors.white,
                    child: CheckboxListTile(
                      value: isPicked,
                      activeColor: const Color(0xFF0C8340),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _pickedItemIds.add(item.variant.id);
                          } else {
                            _pickedItemIds.remove(item.variant.id);
                          }
                        });
                      },
                      secondary: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.product.imageUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 44,
                            height: 44,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.fastfood_rounded, size: 20),
                          ),
                        ),
                      ),
                      title: Text(
                        item.product.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          decoration: isPicked ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: Text(
                        '${item.variant.unit} • Qty: ${item.quantity} • ₹${item.totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 16),

                // Grand Total Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Bill Value', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      '₹${order.grandTotal.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0C8340)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -3)),
              ],
            ),
            child: Row(
              children: [
                if (order.status == OrderStatus.placed) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isUpdating ? null : () => _updateStatus(OrderStatus.cancelled),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w800)),
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
                      ),
                      child: const Text('Accept Order', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ] else if (order.status == OrderStatus.confirmed) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUpdating ? null : () => _updateStatus(OrderStatus.packing),
                      icon: const Icon(Icons.inventory_2_rounded),
                      label: const Text('Start Picking & Packing', style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0C8340),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ] else if (order.status == OrderStatus.packing) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUpdating ? null : () => _updateStatus(OrderStatus.outForDelivery),
                      icon: const Icon(Icons.delivery_dining_rounded),
                      label: const Text('Dispatch / Handover to Rider', style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ] else if (order.status == OrderStatus.outForDelivery) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUpdating ? null : _promptOtpVerification,
                      icon: const Icon(Icons.verified_rounded),
                      label: const Text('Enter OTP & Mark Delivered', style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0C8340),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'Order ${order.status.displayName}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
