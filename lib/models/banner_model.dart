/// Promotional Banner Model conforming to PRD Section 4.3 & 5.10
class BannerModel {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String? deepLink;
  final String? categoryId;
  final String? discountText;
  final String? backgroundColorHex;
  final bool isActive;
  final int displayOrder;

  const BannerModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.deepLink,
    this.categoryId,
    this.discountText,
    this.backgroundColorHex,
    this.isActive = true,
    this.displayOrder = 0,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      imageUrl: json['image_url'] as String,
      deepLink: json['deep_link'] as String?,
      categoryId: json['category_id'] as String?,
      discountText: json['discount_text'] as String?,
      backgroundColorHex: json['background_color_hex'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'image_url': imageUrl,
      'deep_link': deepLink,
      'category_id': categoryId,
      'discount_text': discountText,
      'background_color_hex': backgroundColorHex,
      'is_active': isActive,
      'display_order': displayOrder,
    };
  }
}
