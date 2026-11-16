import 'package:flutter/material.dart';
import '../models/banner_model.dart';
import '../core/constants/app_colors.dart';
import 'qb_ui.dart';

/// Promotional Banner Card for the home carousel / desktop hero (PRD 4.3 & 5.10)
///
/// Deep brand-coloured card with a yellow offer tag, title, subtitle,
/// "Shop now" pill and a rotated yellow tile holding the category glyph.
class PromoBannerCard extends StatelessWidget {
  final BannerModel banner;
  final VoidCallback? onTap;
  final bool large;

  const PromoBannerCard({
    super.key,
    required this.banner,
    this.onTap,
    this.large = false,
  });

  static Color backgroundFor(BannerModel banner) {
    final base = CategoryVisual.parseHex(banner.backgroundColorHex, fallback: AppColors.primary);
    return Color.lerp(base, Colors.black, 0.35)!;
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundFor(banner);
    final visual = CategoryVisual.forCategoryId(banner.categoryId);
    final tileSize = large ? 180.0 : 104.0;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(large ? 24 : 20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              right: large ? -60 : -36,
              top: large ? -80 : -30,
              child: Container(
                width: large ? 380 : 200,
                height: large ? 380 : 200,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              right: large ? 70 : 18,
              top: 0,
              bottom: 0,
              child: Center(
                child: Transform.rotate(
                  angle: -0.14,
                  child: Container(
                    width: tileSize,
                    height: tileSize,
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(tileSize * 0.25)),
                    child: Icon(visual.icon, size: tileSize * 0.56, color: AppColors.primaryDark),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(large ? 40 : 20),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                width: large ? 420 : 200,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (banner.discountText != null && banner.discountText!.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: large ? 10 : 8, vertical: large ? 5 : 4),
                        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          banner.discountText!,
                          style: TextStyle(
                            fontSize: large ? 12 : 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    SizedBox(height: large ? 12 : 8),
                    Text(
                      banner.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: large ? 40 : 20,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: large ? -1.2 : -0.2,
                      ),
                    ),
                    SizedBox(height: large ? 10 : 6),
                    Text(
                      banner.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: large ? 16 : 12),
                    ),
                    SizedBox(height: large ? 16 : 10),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: large ? 22 : 14, vertical: large ? 12 : 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        'Shop now',
                        style: TextStyle(fontSize: large ? 14 : 12, fontWeight: FontWeight.w800, color: bg),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact side promo (desktop hero right column / mobile secondary banner).
class PromoSideCard extends StatelessWidget {
  final BannerModel banner;
  final Color background;
  final Color tagColor;
  final VoidCallback? onTap;

  const PromoSideCard({
    super.key,
    required this.banner,
    this.background = AppColors.accent,
    this.tagColor = AppColors.textPrimary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final visual = CategoryVisual.forCategoryId(banner.categoryId);
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (banner.discountText != null)
                      Text(
                        banner.discountText!,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: tagColor),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      banner.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      banner.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF3B3216)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Icon(visual.icon, size: 34, color: visual.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
