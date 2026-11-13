/// Product Variant Model conforming to PRD Section 4.6
class ProductVariant {
  final String id;
  final String productId;
  final String unit; // e.g. "500 ml", "1 kg", "Pack of 2"
  final double mrp;
  final double sellingPrice;
  final int stockQuantity;
  final String? sku;

  const ProductVariant({
    required this.id,
    required this.productId,
    required this.unit,
    required this.mrp,
    required this.sellingPrice,
    required this.stockQuantity,
    this.sku,
  });

  int get discountPercentage {
    if (mrp <= sellingPrice || mrp <= 0) return 0;
    return (((mrp - sellingPrice) / mrp) * 100).round();
  }

  bool get isOutOfStock => stockQuantity <= 0;

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      unit: json['unit'] as String,
      mrp: (json['mrp'] as num).toDouble(),
      sellingPrice: (json['selling_price'] as num).toDouble(),
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
      sku: json['sku'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'unit': unit,
      'mrp': mrp,
      'selling_price': sellingPrice,
      'stock_quantity': stockQuantity,
      'sku': sku,
    };
  }

  ProductVariant copyWith({
    String? id,
    String? productId,
    String? unit,
    double? mrp,
    double? sellingPrice,
    int? stockQuantity,
    String? sku,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      unit: unit ?? this.unit,
      mrp: mrp ?? this.mrp,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      sku: sku ?? this.sku,
    );
  }
}

/// Product Model conforming to PRD Section 4.5 & 4.6
class ProductModel {
  final String id;
  final String name;
  final String brand;
  final String categoryId;
  final String description;
  final String imageUrl;
  final List<String> additionalImages;
  final List<ProductVariant> variants;
  final bool isFeatured;
  final bool isBestSeller;
  final double rating;
  final int reviewCount;

  const ProductModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.categoryId,
    required this.description,
    required this.imageUrl,
    this.additionalImages = const [],
    this.variants = const [],
    this.isFeatured = false,
    this.isBestSeller = false,
    this.rating = 4.5,
    this.reviewCount = 0,
  });

  ProductVariant get defaultVariant => variants.isNotEmpty
      ? variants.first
      : ProductVariant(
          id: '$id-default',
          productId: id,
          unit: '1 unit',
          mrp: 0.0,
          sellingPrice: 0.0,
          stockQuantity: 0,
        );

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String? ?? 'Quick Basket',
      categoryId: json['category_id'] as String,
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      additionalImages: (json['additional_images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      variants: (json['variants'] as List<dynamic>?)
              ?.map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
              .toList() ??
          const [],
      isFeatured: json['is_featured'] as bool? ?? false,
      isBestSeller: json['is_best_seller'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'category_id': categoryId,
      'description': description,
      'image_url': imageUrl,
      'additional_images': additionalImages,
      'variants': variants.map((v) => v.toJson()).toList(),
      'is_featured': isFeatured,
      'is_best_seller': isBestSeller,
      'rating': rating,
      'review_count': reviewCount,
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? brand,
    String? categoryId,
    String? description,
    String? imageUrl,
    List<String>? additionalImages,
    List<ProductVariant>? variants,
    bool? isFeatured,
    bool? isBestSeller,
    double? rating,
    int? reviewCount,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      additionalImages: additionalImages ?? this.additionalImages,
      variants: variants ?? this.variants,
      isFeatured: isFeatured ?? this.isFeatured,
      isBestSeller: isBestSeller ?? this.isBestSeller,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }
}
