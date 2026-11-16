import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/category_model.dart';
import 'qb_ui.dart';

/// Category tile for category grids (PRD Section 4.4)
///
/// Square tinted tile with the category glyph and its name underneath.
/// When [size] is null the tile stretches to the available width.
class CategoryItem extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback? onTap;
  final double? size;
  final double radius;
  final double fontSize;
  final bool showLabel;

  const CategoryItem({
    super.key,
    required this.category,
    this.onTap,
    this.size = 64,
    this.radius = 18,
    this.fontSize = 11.5,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final visual = CategoryVisual.of(category);

    final tile = LayoutBuilder(
      builder: (context, constraints) {
        final side = size ?? constraints.maxWidth;
        return Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            color: visual.tint,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.04)),
          ),
          clipBehavior: Clip.antiAlias,
          child: category.imageUrl != null && category.imageUrl!.startsWith('http')
              ? Image.network(
                  category.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(visual.icon, color: visual.ink, size: side * 0.48),
                )
              : Icon(visual.icon, color: visual.ink, size: side * 0.48),
        );
      },
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (size == null) AspectRatio(aspectRatio: 1, child: tile) else tile,
          if (showLabel) ...[
            const SizedBox(height: 6),
            Text(
              category.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, height: 1.25),
            ),
          ],
        ],
      ),
    );
  }
}
