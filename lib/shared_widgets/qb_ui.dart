import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/category_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../services/mock_data_service.dart';

/// Shared building blocks for the Quick Basket redesign (customer + admin).

/// Layout breakpoints used across the app.
class Responsive {
  Responsive._();

  static const double tablet = 700;
  static const double desktop = 1024;

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;
  static bool isMobile(BuildContext context) => width(context) < tablet;
  static bool isTablet(BuildContext context) => width(context) >= tablet && width(context) < desktop;
  static bool isDesktop(BuildContext context) => width(context) >= desktop;
}

/// Standard white card decoration with hairline border and soft shadow.
BoxDecoration qbCard({
  Color color = Colors.white,
  Color borderColor = AppColors.border,
  double radius = 18,
  double borderWidth = 1,
  bool shadow = false,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor, width: borderWidth),
    boxShadow: shadow
        ? [
            BoxShadow(
              color: const Color(0xFF102818).withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ]
        : null,
  );
}

/// Formats a rupee amount the Indian way (₹1,23,456).
String qbRupees(num value) {
  final negative = value < 0;
  final digits = value.abs().round().toString();
  String out;
  if (digits.length <= 3) {
    out = digits;
  } else {
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    out = '${parts.join(',')},$last3';
  }
  return '${negative ? '-' : ''}₹$out';
}

/// Quick Basket wordmark: yellow tile with a basket glyph + lowercase name.
class QbLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color textColor;
  final String? caption;

  const QbLogo({
    super.key,
    this.size = 42,
    this.showText = true,
    this.textColor = AppColors.textPrimary,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(size * 0.29),
          ),
          child: Icon(Icons.shopping_basket_outlined, color: AppColors.primaryDark, size: size * 0.56),
        ),
        if (showText) ...[
          SizedBox(width: size * 0.24),
          Flexible(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'quick basket',
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  fontSize: size * 0.48,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: textColor,
                  height: 1.1,
                ),
              ),
              if (caption != null)
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: AppColors.primaryDeep,
                  ),
                ),
            ],
          ),
          ),
        ],
      ],
    );
  }
}

/// Visual identity (icon + tint + ink) for a category.
class CategoryVisual {
  final IconData icon;
  final Color tint;
  final Color ink;

  const CategoryVisual(this.icon, this.tint, this.ink);

  static const Map<String, CategoryVisual> _byIcon = {
    'eco': CategoryVisual(Icons.eco_outlined, Color(0xFFE3F4E6), Color(0xFF1E7A3C)),
    'egg': CategoryVisual(Icons.egg_outlined, Color(0xFFFFF4D1), Color(0xFF946200)),
    'grain': CategoryVisual(Icons.grain_rounded, Color(0xFFFFEBD6), Color(0xFFA0521B)),
    'fastfood': CategoryVisual(Icons.fastfood_outlined, Color(0xFFFDE5DF), Color(0xFFB23A21)),
    'local_drink': CategoryVisual(Icons.local_drink_outlined, Color(0xFFDFF1FB), Color(0xFF1D6A93)),
    'breakfast_dining': CategoryVisual(Icons.breakfast_dining_outlined, Color(0xFFF2E6F7), Color(0xFF7A3B94)),
    'ramen_dining': CategoryVisual(Icons.ramen_dining_outlined, Color(0xFFFCE4E6), Color(0xFFB3263A)),
    'coffee': CategoryVisual(Icons.coffee_outlined, Color(0xFFEFE7E1), Color(0xFF6E4630)),
    'cake': CategoryVisual(Icons.cake_outlined, Color(0xFFFCE4EF), Color(0xFFA8285E)),
    'bakery_dining': CategoryVisual(Icons.bakery_dining_outlined, Color(0xFFECE6F7), Color(0xFF5B3FA0)),
    'spa': CategoryVisual(Icons.spa_outlined, Color(0xFFDDF3F5), Color(0xFF17707A)),
    'child_care': CategoryVisual(Icons.child_care_outlined, Color(0xFFF4F7DC), Color(0xFF5E6B12)),
    'home': CategoryVisual(Icons.home_outlined, Color(0xFFE6E9F6), Color(0xFF3E4C94)),
    'cleaning_services': CategoryVisual(Icons.cleaning_services_outlined, Color(0xFFDDF1EC), Color(0xFF17705C)),
    'pets': CategoryVisual(Icons.pets_outlined, Color(0xFFFFF7D6), Color(0xFF8A6A00)),
  };

  static Color parseHex(String? hex, {Color fallback = AppColors.primaryLight}) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      var clean = hex.replaceFirst('#', '');
      if (clean.length == 6) clean = 'ff$clean';
      return Color(int.parse(clean, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  static CategoryVisual of(CategoryModel? category) {
    if (category == null) {
      return const CategoryVisual(Icons.shopping_basket_outlined, AppColors.primaryLight, AppColors.primary);
    }
    final known = _byIcon[category.iconName];
    if (known != null) return known;
    return CategoryVisual(
      Icons.shopping_basket_outlined,
      parseHex(category.colorHex),
      AppColors.primaryDeep,
    );
  }

  static CategoryVisual forCategoryId(String? categoryId, [List<CategoryModel>? categories]) {
    final list = categories ?? MockDataService.categories;
    for (final c in list) {
      if (c.id == categoryId) return of(c);
    }
    for (final c in MockDataService.categories) {
      if (c.id == categoryId) return of(c);
    }
    return of(null);
  }
}

/// Product photo inside a tinted rounded tile, with an icon fallback.
class QbProductImage extends StatelessWidget {
  final ProductModel product;
  final double? height;
  final double? width;
  final double radius;
  final double iconSize;

  const QbProductImage({
    super.key,
    required this.product,
    this.height,
    this.width,
    this.radius = 12,
    this.iconSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    final visual = CategoryVisual.forCategoryId(product.categoryId);
    final fallback = Center(child: Icon(visual.icon, size: iconSize, color: visual.ink));
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(color: visual.tint, borderRadius: BorderRadius.circular(radius)),
      clipBehavior: Clip.antiAlias,
      child: product.imageUrl.isEmpty
          ? fallback
          : Image.network(
              product.imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => fallback,
              loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
            ),
    );
  }
}

/// Filled green − qty + stepper.
class QbQtyStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final int? maxQuantity;
  final VoidCallback? onMaxReached;
  final double height;
  final double width;
  final double fontSize;

  const QbQtyStepper({
    super.key,
    required this.quantity,
    this.onIncrement,
    this.onDecrement,
    this.maxQuantity,
    this.onMaxReached,
    this.height = 34,
    this.width = 76,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final isMax = maxQuantity != null && quantity >= maxQuantity!;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onDecrement,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
              child: Semantics(
                button: true,
                label: 'Remove one',
                child: const Center(child: Icon(Icons.remove_rounded, size: 16, color: Colors.white)),
              ),
            ),
          ),
          Text('$quantity', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: fontSize)),
          Expanded(
            child: InkWell(
              onTap: isMax ? (onMaxReached ?? onIncrement) : onIncrement,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
              child: Semantics(
                button: true,
                label: isMax ? 'Maximum stock reached' : 'Add one',
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: isMax ? Colors.white38 : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Outlined green ADD button.
class QbAddButton extends StatelessWidget {
  final VoidCallback? onTap;
  final double height;
  final double width;
  final double fontSize;

  const QbAddButton({super.key, this.onTap, this.height = 34, this.width = 66, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryTint,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: height,
          width: width,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: Text(
            'ADD',
            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: fontSize),
          ),
        ),
      ),
    );
  }
}

/// Rounded pill used for statuses, badges and chips.
class QbPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final bool dot;
  final double fontSize;
  final EdgeInsets padding;

  const QbPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.dot = false,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: foreground, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title row with an optional "See all" link.
class QbSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double fontSize;
  final EdgeInsets padding;

  const QbSectionHeader({
    super.key,
    required this.title,
    this.actionLabel = 'See all',
    this.onAction,
    this.fontSize = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, letterSpacing: -0.3),
            ),
          ),
          if (onAction != null && actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 36),
              ),
              child: Text(actionLabel!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

/// Small grey "12 MINS" delivery chip.
class QbEtaChip extends StatelessWidget {
  final String label;
  const QbEtaChip({super.key, this.label = '12 MINS'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, size: 11, color: AppColors.textBody),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textBody)),
        ],
      ),
    );
  }
}

/// Yellow tab hanging from the top edge of an image ("18% OFF").
class QbDiscountTab extends StatelessWidget {
  final String label;
  final double fontSize;
  const QbDiscountTab({super.key, required this.label, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: const BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
      ),
      child: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
    );
  }
}

/// Status colours for an order, shared by customer & admin screens.
class OrderStatusStyle {
  final String label;
  final Color background;
  final Color foreground;

  const OrderStatusStyle(this.label, this.background, this.foreground);

  static OrderStatusStyle of(OrderStatus status) {
    switch (status) {
      case OrderStatus.placed:
        return const OrderStatusStyle('Placed', AppColors.accentLight, AppColors.accentInk);
      case OrderStatus.confirmed:
        return const OrderStatusStyle('Confirmed', Color(0xFFF1ECFA), Color(0xFF5B3FA0));
      case OrderStatus.packing:
        return const OrderStatusStyle('Packing', AppColors.infoLight, Color(0xFF34479A));
      case OrderStatus.outForDelivery:
        return const OrderStatusStyle('Out for Delivery', AppColors.primaryLight, AppColors.primaryDeep);
      case OrderStatus.delivered:
        return const OrderStatusStyle('Delivered', AppColors.primaryLight, AppColors.primaryDeep);
      case OrderStatus.cancelled:
        return const OrderStatusStyle('Cancelled', AppColors.errorLight, AppColors.error);
    }
  }
}

/// Selectable radio indicator used on address/payment cards.
class QbRadioDot extends StatelessWidget {
  final bool selected;
  const QbRadioDot({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? AppColors.primary : AppColors.borderStrong, width: 2),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle))
          : null,
    );
  }
}

/// Formats a time like "10:42 AM".
String qbTime(DateTime dt) {
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${dt.hour >= 12 ? 'PM' : 'AM'}';
}

/// "Today, 10:42 AM" / "Yesterday, 7:15 PM" / "12 Nov, 9:02 AM".
String qbFriendlyDate(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  if (diff == 0) return 'Today, ${qbTime(dt)}';
  if (diff == 1) return 'Yesterday, ${qbTime(dt)}';
  return '${dt.day} ${months[dt.month - 1]}, ${qbTime(dt)}';
}

/// "just now" / "4 min" / "2 hr" age label.
String qbAge(DateTime dt) {
  final mins = DateTime.now().difference(dt).inMinutes;
  if (mins < 1) return 'now';
  if (mins < 60) return '$mins min';
  final hrs = mins ~/ 60;
  if (hrs < 24) return '$hrs hr';
  return '${hrs ~/ 24} d';
}
