import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/product_model.dart';
import 'qb_ui.dart';

/// Product Details Modal Bottom Sheet conforming to PRD Section 4.6
///
/// Large product image, brand + ETA, price with savings, unit (variant)
/// selector, product details and a sticky "Add to cart" / stepper footer.
class ProductDetailsSheet extends StatefulWidget {
  final ProductModel product;
  final int initialQuantity;
  final Function(ProductModel, ProductVariant) onAddToCart;
  final Function(ProductModel, ProductVariant) onIncrement;
  final Function(ProductModel, ProductVariant) onDecrement;

  const ProductDetailsSheet({
    super.key,
    required this.product,
    this.initialQuantity = 0,
    required this.onAddToCart,
    required this.onIncrement,
    required this.onDecrement,
  });

  static Future<void> show(
    BuildContext context, {
    required ProductModel product,
    required int initialQuantity,
    required Function(ProductModel, ProductVariant) onAddToCart,
    required Function(ProductModel, ProductVariant) onIncrement,
    required Function(ProductModel, ProductVariant) onDecrement,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) => ProductDetailsSheet(
        product: product,
        initialQuantity: initialQuantity,
        onAddToCart: onAddToCart,
        onIncrement: onIncrement,
        onDecrement: onDecrement,
      ),
    );
  }

  @override
  State<ProductDetailsSheet> createState() => _ProductDetailsSheetState();
}

class _ProductDetailsSheetState extends State<ProductDetailsSheet> {
  late ProductVariant _selectedVariant;
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _selectedVariant = widget.product.defaultVariant;
    _quantity = widget.initialQuantity;
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final discount = _selectedVariant.discountPercentage;
    final isOutOfStock = _selectedVariant.isOutOfStock;
    final saving = _selectedVariant.mrp - _selectedVariant.sellingPrice;
    final variants = product.variants.isEmpty ? [product.defaultVariant] : product.variants;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                SizedBox(
                  height: 270,
                  child: Stack(
                    children: [
                      Positioned.fill(child: QbProductImage(product: product, radius: 20, iconSize: 110)),
                      if (discount > 0)
                        Positioned(
                          top: 14,
                          left: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
                            child: Text('$discount% OFF', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 2,
                          shadowColor: Colors.black26,
                          child: IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      product.brand.toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 8),
                    const QbEtaChip(),
                    const Spacer(),
                    const Icon(Icons.star_rounded, size: 16, color: Color(0xFFE0A100)),
                    const SizedBox(width: 2),
                    Text(
                      '${product.rating.toStringAsFixed(1)}${product.reviewCount > 0 ? ' (${product.reviewCount})' : ''}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textBody),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  product.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.2),
                ),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 8,
                  children: [
                    Text('₹${_selectedVariant.sellingPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    if (discount > 0) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          'MRP ₹${_selectedVariant.mrp.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 14, color: AppColors.textMuted, decoration: TextDecoration.lineThrough),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          'Save ₹${saving.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ],
                ),
                const Text('Inclusive of all taxes', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 18),
                const Text('Select unit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = (constraints.maxWidth - 16) / 3;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: variants.map((variant) {
                        final isSelected = variant.id == _selectedVariant.id;
                        final out = variant.isOutOfStock;
                        return SizedBox(
                          width: w,
                          child: Material(
                            color: isSelected ? AppColors.primaryTint : (out ? const Color(0xFFFAFBFA) : Colors.white),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isSelected ? AppColors.primary : AppColors.borderStrong,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => setState(() => _selectedVariant = variant),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      variant.unit,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                        color: out ? AppColors.textMuted : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    if (out)
                                      const Text('Out of stock',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted))
                                    else
                                      Text.rich(
                                        TextSpan(children: [
                                          TextSpan(text: '₹${variant.sellingPrice.toStringAsFixed(0)} '),
                                          if (variant.mrp > variant.sellingPrice)
                                            TextSpan(
                                              text: '₹${variant.mrp.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                color: AppColors.textMuted,
                                                fontWeight: FontWeight.w500,
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ),
                                        ]),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Product details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(
                        product.description.isEmpty ? 'Fresh, quality-checked and delivered in minutes.' : product.description,
                        style: const TextStyle(fontSize: 13, color: AppColors.textBody, height: 1.55),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          _fact('Brand', product.brand),
                          _fact('Unit', _selectedVariant.unit),
                          if (_selectedVariant.sku != null) _fact('SKU', _selectedVariant.sku!),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Guarantee(Icons.verified_outlined, 'Quality\nchecked'),
                    _Guarantee(Icons.bolt_rounded, '12-minute\ndelivery'),
                    _Guarantee(Icons.replay_rounded, 'Easy\nreturns'),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_selectedVariant.unit, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text('₹${_selectedVariant.sellingPrice.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: isOutOfStock
                        ? Container(
                            height: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(14)),
                            child: const Text('Out of stock',
                                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                          )
                        : _quantity > 0
                            ? QbQtyStepper(
                                quantity: _quantity,
                                height: 54,
                                width: double.infinity,
                                fontSize: 17,
                                onDecrement: () {
                                  setState(() => _quantity--);
                                  widget.onDecrement(widget.product, _selectedVariant);
                                },
                                onIncrement: () {
                                  if (_quantity >= _selectedVariant.stockQuantity) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Max available stock reached')),
                                    );
                                    return;
                                  }
                                  setState(() => _quantity++);
                                  widget.onIncrement(widget.product, _selectedVariant);
                                },
                              )
                            : ElevatedButton.icon(
                                onPressed: () {
                                  setState(() => _quantity = 1);
                                  widget.onAddToCart(widget.product, _selectedVariant);
                                },
                                icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                                label: const Text('Add to cart', style: TextStyle(fontSize: 16)),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(54),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fact(String label, String value) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: '$label · ', style: const TextStyle(color: AppColors.textSecondary)),
        TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
      style: const TextStyle(fontSize: 12),
    );
  }
}

class _Guarantee extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Guarantee(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, height: 1.2)),
      ],
    );
  }
}
