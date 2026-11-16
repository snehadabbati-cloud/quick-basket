import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../screens/order_tracking_screen.dart';

/// Order history card (PRD 4.10): number, date, status pill, item thumbnails,
/// total and actions — Track order (active) or View details + Reorder (past).
class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onReorder;
  final VoidCallback? onTrack;

  const OrderCard({
    super.key,
    required this.order,
    required this.onReorder,
    this.onTrack,
  });

  bool get _isActive => order.status != OrderStatus.delivered && order.status != OrderStatus.cancelled;

  @override
  Widget build(BuildContext context) {
    final style = OrderStatusStyle.of(order.status);
    final itemCount = order.items.fold<int>(0, (sum, i) => sum + i.quantity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: qbCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order ${_number(order.orderNumber)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(qbFriendlyDate(order.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              QbPill(label: order.status.displayName, background: style.background, foreground: style.foreground),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => showDetails(context),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                SizedBox(
                  height: 40,
                  width: 40.0 + (order.items.take(3).length - 1).clamp(0, 2) * 32,
                  child: Stack(
                    children: [
                      for (var i = 0; i < order.items.take(3).length; i++)
                        Positioned(
                          left: i * 32.0,
                          child: Container(
                            width: 40,
                            height: 40,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            child: QbProductImage(product: order.items[i].product, radius: 10, iconSize: 18),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
                ),
                Text('₹${order.grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_isActive)
            ElevatedButton.icon(
              onPressed: onTrack ??
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: order))),
              icon: const Icon(Icons.location_on_outlined, size: 18),
              label: const Text('Track order'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showDetails(context),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                    child: const Text('View details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReorder,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      backgroundColor: AppColors.primaryTint,
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    child: const Text('Reorder'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _number(String n) => n.startsWith('#') ? n : '#$n';

  /// Bottom sheet with the full item list and bill for this order.
  void showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final style = OrderStatusStyle.of(order.status);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
          child: SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text('Order ${_number(order.orderNumber)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    QbPill(label: order.status.displayName, background: style.background, foreground: style.foreground),
                  ],
                ),
                const SizedBox(height: 4),
                Text(qbFriendlyDate(order.createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                if (order.address != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${order.address!.type} · ${order.address!.formattedAddress}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textBody),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Items', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ...order.items.map(
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(width: 44, height: 44, child: QbProductImage(product: i.product, iconSize: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(i.product.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('${i.variant.unit} × ${i.quantity}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Text('₹${i.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),
                _billRow('Item total', order.itemTotal),
                _billRow('Delivery fee', order.deliveryFee, freeIfZero: true),
                _billRow('Packaging fee', order.packagingFee),
                if (order.tipAmount > 0) _billRow('Delivery partner tip', order.tipAmount),
                if (order.discountAmount > 0) _billRow('Discount', -order.discountAmount),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Expanded(child: Text('Total paid', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                    Text('₹${order.grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Paid via ${order.paymentMethod == 'cod' ? 'Cash on Delivery' : 'UPI / Card'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onReorder();
                  },
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('Reorder these items'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _billRow(String label, double value, {bool freeIfZero = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textBody))),
          Text(
            freeIfZero && value == 0
                ? 'FREE'
                : value < 0
                    ? '−₹${(-value).toStringAsFixed(0)}'
                    : '₹${value.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: (freeIfZero && value == 0) || value < 0 ? AppColors.primaryDeep : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
