/// Category Model conforming to PRD Section 4.4 and Database Schema
class CategoryModel {
  final String id;
  final String name;
  final String slug;
  final String? imageUrl;
  final String? iconName;
  final String? colorHex;
  final int displayOrder;
  final bool isActive;
  final List<String> subcategories;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    this.iconName,
    this.colorHex,
    this.displayOrder = 0,
    this.isActive = true,
    this.subcategories = const [],
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      iconName: json['icon_name'] as String?,
      colorHex: json['color_hex'] as String?,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      subcategories: (json['subcategories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'image_url': imageUrl,
      'icon_name': iconName,
      'color_hex': colorHex,
      'display_order': displayOrder,
      'is_active': isActive,
      'subcategories': subcategories,
    };
  }
}
