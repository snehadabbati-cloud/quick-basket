import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/category_model.dart';

/// Category Item Card for Home Category Grid (PRD Section 4.4)
class CategoryItem extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback? onTap;

  const CategoryItem({
    super.key,
    required this.category,
    this.onTap,
  });

  IconData _getCategoryIcon(String? iconName) {
    switch (iconName) {
      case 'eco':
        return Icons.eco_rounded;
      case 'egg':
        return Icons.egg_rounded;
      case 'grain':
        return Icons.grain_rounded;
      case 'fastfood':
        return Icons.fastfood_rounded;
      case 'local_drink':
        return Icons.local_drink_rounded;
      case 'breakfast_dining':
        return Icons.breakfast_dining_rounded;
      case 'ramen_dining':
        return Icons.ramen_dining_rounded;
      case 'coffee':
        return Icons.coffee_rounded;
      case 'cake':
        return Icons.cake_rounded;
      case 'bakery_dining':
        return Icons.bakery_dining_rounded;
      case 'spa':
        return Icons.spa_rounded;
      case 'child_care':
        return Icons.child_care_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'cleaning_services':
        return Icons.cleaning_services_rounded;
      case 'pets':
        return Icons.pets_rounded;
      default:
        return Icons.shopping_basket_rounded;
    }
  }

  Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return AppColors.primaryLight;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return AppColors.primaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _parseColor(category.colorHex);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.04),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                _getCategoryIcon(category.iconName),
                color: AppColors.primary,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 72,
            child: Text(
              category.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
