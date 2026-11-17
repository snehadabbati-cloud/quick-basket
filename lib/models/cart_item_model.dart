import 'product_model.dart';

/// Cart Item Model conforming to PRD Section 4.8
class CartItemModel {
  final ProductModel product;
  ProductVariant variant;
  int quantity;

  CartItemModel({
    required this.product,
    required this.variant,
    this.quantity = 1,
  });

  double get totalPrice => variant.sellingPrice * quantity;
  double get totalMrp => variant.mrp * quantity;
  double get totalSavings => (variant.mrp - variant.sellingPrice) * quantity;

  Map<String, dynamic> toJson() {
    return {
      'product_id': product.id,
      'variant_id': variant.id,
      'quantity': quantity,
      'unit_price': variant.sellingPrice,
      'total_price': totalPrice,
    };
  }
}
