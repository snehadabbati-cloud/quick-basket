/// Subcategory Model conforming to PRD Section 4.4 and Database Schema
class SubcategoryModel {
  final String id;
  final String categoryId;
  final String name;
  final String slug;
  final String? imageUrl;
  final int displayOrder;
  final bool isActive;
  final DateTime? createdAt;

  const SubcategoryModel({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.slug,
    this.imageUrl,
    this.displayOrder = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory SubcategoryModel.fromJson(Map<String, dynamic> json) {
    return SubcategoryModel(
      id: json['id'] as String,
      categoryId: json['category_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'slug': slug,
      'image_url': imageUrl,
      'display_order': displayOrder,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  SubcategoryModel copyWith({
    String? id,
    String? categoryId,
    String? name,
    String? slug,
    String? imageUrl,
    int? displayOrder,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return SubcategoryModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      imageUrl: imageUrl ?? this.imageUrl,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
