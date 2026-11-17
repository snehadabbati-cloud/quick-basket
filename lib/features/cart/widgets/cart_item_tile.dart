import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/cart_item_model.dart';
import '../../../shared_widgets/qb_ui.dart';

/// One cart line: product image, name/unit, quantity stepper and line price.
class CartItemTile extends StatelessWidget {
  final CartItemModel item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool showDivider;
  final bool compact;

  const CartItemTile({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    this.showDivider = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final variant = item.variant;
    final product = item.product;
    final hasDiscount = variant.mrp > variant.sellingPrice;
    final isOut = variant.isOutOfStock || variant.stockQuantity <= 0;
    final isMaxReached = !isOut && item.quantity >= variant.stockQuantity;
    final isLowStock = !isOut && variant.stockQuantity <= 3;
    final imageSize = compact ? 52.0 : 60.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 14, vertical: compact ? 8 : 12),
      decoration: BoxDecoration(
        border: showDivider ? const Border(bottom: BorderSide(color: AppColors.divider)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: imageSize,
            height: imageSize,
            child: QbProductImage(product: product, iconSize: imageSize * 0.5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
                ),
                const SizedBox(height: 2),
                Text(
                  compact ? '${variant.unit} · ₹${item.totalPrice.toStringAsFixed(0)}' : variant.unit,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (isOut) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'OUT OF STOCK · Remove to checkout',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.error),
                  ),
                ] else if (isMaxReached) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Max ${variant.stockQuantity} in stock',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFE65100)),
                  ),
                ] else if (isLowStock) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Only ${variant.stockQuantity} left',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFE65100)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              QbQtyStepper(
                quantity: item.quantity,
                maxQuantity: variant.stockQuantity,
                onIncrement: onIncrement,
                onDecrement: onDecrement,
                height: compact ? 34 : 32,
                width: compact ? 84 : 76,
              ),
              if (!compact) ...[
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '₹${item.totalPrice.toStringAsFixed(0)} ',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      if (hasDiscount)
                        TextSpan(
                          text: '₹${item.totalMrp.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
