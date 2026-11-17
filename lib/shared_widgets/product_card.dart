import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/product_model.dart';
import 'qb_ui.dart';

/// Quick Commerce Product Card (PRD Section 4.5 & 4.6)
///
/// Tinted image tile with a yellow discount tab, delivery ETA chip, name, unit,
/// price/MRP and an ADD button that turns into a green quantity stepper.
/// When [width] is null the card fills its parent (grid cells).
class ProductCard extends StatelessWidget {
  final ProductModel product;
  final int cartQuantity;
  final VoidCallback? onAddToCart;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback? onTap;
  final double? width;
  final double imageHeight;
  final bool large;

  const ProductCard({
    super.key,
    required this.product,
    this.cartQuantity = 0,
    this.onAddToCart,
    this.onIncrement,
    this.onDecrement,
    this.onTap,
    this.width,
    this.imageHeight = 112,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final variant = product.defaultVariant;
    final discount = variant.discountPercentage;
    final isOutOfStock = variant.isOutOfStock;
    final isLowStock = !isOutOfStock && variant.stockQuantity > 0 && variant.stockQuantity <= 3;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(large ? 18 : 16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: const Color(0xFF102818).withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: EdgeInsets.all(large ? 10 : 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final image = InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Positioned.fill(child: QbProductImage(product: product, radius: large ? 14 : 12, iconSize: large ? 56 : 44)),
                if (discount > 0)
                  Positioned(top: 0, left: 8, child: QbDiscountTab(label: '$discount% OFF', fontSize: large ? 11 : 10)),
                if (isLowStock)
                  Positioned(
                    top: discount > 0 ? (large ? 24 : 22) : 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFFB74D), width: 0.8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on_rounded, size: 10, color: Color(0xFFE65100)),
                          const SizedBox(width: 2),
                          Text(
                            'Only ${variant.stockQuantity} left',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isOutOfStock)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'OUT OF STOCK',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (constraints.hasBoundedHeight)
                Expanded(child: image)
              else
                SizedBox(height: large ? 150 : imageHeight, child: image),
              const SizedBox(height: 6),
              const QbEtaChip(),
              const SizedBox(height: 6),
              InkWell(
                onTap: onTap,
                child: SizedBox(
                  height: large ? 36 : 34,
                  child: Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: large ? 14 : 13, fontWeight: FontWeight.w600, height: 1.3),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                variant.unit,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: large ? 13 : 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹${variant.sellingPrice.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: large ? 16 : 14, fontWeight: FontWeight.w800),
                        ),
                        if (discount > 0)
                          Text(
                            '₹${variant.mrp.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: large ? 12 : 11,
                              color: AppColors.textMuted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isOutOfStock)
                    Container(
                      height: large ? 38 : 34,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(10)),
                      child: const Text('Sold out',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                    )
                  else if (cartQuantity == 0)
                    QbAddButton(
                      onTap: onAddToCart,
                      height: large ? 38 : 34,
                      width: large ? 80 : 64,
                      fontSize: large ? 14 : 13,
                    )
                  else
                    QbQtyStepper(
                      quantity: cartQuantity,
                      maxQuantity: variant.stockQuantity,
                      onIncrement: onIncrement,
                      onDecrement: onDecrement,
                      height: large ? 38 : 34,
                      width: large ? 92 : 74,
                      fontSize: large ? 14 : 13,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
