import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../models/category_model.dart';
import '../../../shared_widgets/qb_ui.dart';

/// Green mobile home header: delivery ETA, address picker, profile, search.
class MobileHomeHeader extends StatelessWidget {
  final String addressLabel;
  final String addressLine;
  final VoidCallback onAddressTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSearchTap;

  const MobileHomeHeader({
    super.key,
    required this.addressLabel,
    required this.addressLine,
    required this.onAddressTap,
    required this.onProfileTap,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DELIVERY IN',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: AppColors.accent, size: 26),
                        SizedBox(width: 4),
                        Text(
                          '12 minutes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: onAddressTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text(
                              addressLabel,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                            Flexible(
                              child: Text(
                                ' · $addressLine',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: Colors.white.withValues(alpha: 0.16),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Profile',
                  onPressed: onProfileTap,
                  icon: const Icon(Icons.person_outline_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            elevation: 0,
            shadowColor: Colors.transparent,
            child: InkWell(
              onTap: onSearchTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF042814).withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 6)),
                  ],
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppColors.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        AppStrings.searchHint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                      ),
                    ),
                    Container(width: 1, height: 22, color: const Color(0xFFE2E8E4)),
                    const SizedBox(width: 10),
                    const Icon(Icons.mic_none_rounded, color: AppColors.textBody),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Five-tab bottom navigation with a top indicator and cart badge.
class QbBottomNav extends StatelessWidget {
  final int currentIndex;
  final int cartCount;
  final ValueChanged<int> onTap;

  const QbBottomNav({super.key, required this.currentIndex, required this.cartCount, required this.onTap});

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, AppStrings.navHome),
    (Icons.grid_view_outlined, Icons.grid_view_rounded, AppStrings.navCategories),
    (Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, AppStrings.navCart),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, AppStrings.navOrders),
    (Icons.person_outline_rounded, Icons.person_rounded, AppStrings.navProfile),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: SizedBox(
              height: 66,
              child: Row(
                children: List.generate(_items.length, (i) {
                  final item = _items[i];
                  final active = i == currentIndex;
                  final color = active ? AppColors.primary : AppColors.textSecondary;
                  Widget icon = Icon(active ? item.$2 : item.$1, size: 22, color: color);
                  if (i == 2 && cartCount > 0) {
                    icon = Badge(
                      label: Text('$cartCount', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10)),
                      backgroundColor: AppColors.accent,
                      textColor: AppColors.textPrimary,
                      child: icon,
                    );
                  }
                  return Expanded(
                    child: Semantics(
                      selected: active,
                      button: true,
                      label: item.$3,
                      child: InkWell(
                        onTap: () => onTap(i),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (active)
                              Positioned(
                                top: 0,
                                child: Container(
                                  width: 28,
                                  height: 3,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(3)),
                                  ),
                                ),
                              ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                icon,
                                const SizedBox(height: 3),
                                Text(
                                  item.$3,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Green floating "N items · ₹X — View cart" bar.
class CartFloatingBar extends StatelessWidget {
  final int itemCount;
  final double total;
  final String subtitle;
  final VoidCallback onTap;

  const CartFloatingBar({
    super.key,
    required this.itemCount,
    required this.total,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        elevation: 6,
        shadowColor: AppColors.primary.withValues(alpha: 0.45),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$itemCount ${itemCount == 1 ? 'item' : 'items'} · ₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View cart', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary)),
                      Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textPrimary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop storefront header with logo, delivery, search, links, cart button
/// and a horizontal category menu.
class DesktopShopHeader extends StatelessWidget {
  final String addressLine;
  final VoidCallback onAddressTap;
  final VoidCallback onSearchTap;
  final VoidCallback onLogoTap;
  final VoidCallback onOrdersTap;
  final VoidCallback onAccountTap;
  final VoidCallback onCartTap;
  final int cartCount;
  final double cartTotal;
  final List<CategoryModel> categories;
  final ValueChanged<CategoryModel> onCategoryTap;
  final int activeTab;

  const DesktopShopHeader({
    super.key,
    required this.addressLine,
    required this.onAddressTap,
    required this.onSearchTap,
    required this.onLogoTap,
    required this.onOrdersTap,
    required this.onAccountTap,
    required this.onCartTap,
    required this.cartCount,
    required this.cartTotal,
    required this.categories,
    required this.onCategoryTap,
    required this.activeTab,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1280;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 14, 32, 10),
                child: Row(
                  children: [
                    InkWell(
                      onTap: onLogoTap,
                      borderRadius: BorderRadius.circular(12),
                      child: QbLogo(size: 42, showText: !compact),
                    ),
                    SizedBox(width: compact ? 16 : 24),
                    Container(width: 1, height: 40, color: AppColors.border),
                    SizedBox(width: compact ? 14 : 20),
                    Flexible(
                      child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: compact ? 210 : 270),
                      child: InkWell(
                      onTap: onAddressTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.bolt_rounded, color: AppColors.primary, size: 18),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Delivery in 12 minutes',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    addressLine,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                      ),
                    ),
                    SizedBox(width: compact ? 16 : 24),
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: onSearchTap,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F6F4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.search_rounded, color: AppColors.primary),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  AppStrings.searchHint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 15, color: AppColors.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 10 : 20),
                    _link('Orders', Icons.receipt_long_outlined, onOrdersTap, activeTab == 3, compact),
                    SizedBox(width: compact ? 2 : 8),
                    _link('Account', Icons.person_outline_rounded, onAccountTap, activeTab == 4, compact),
                    SizedBox(width: compact ? 8 : 12),
                    Material(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: onCartTap,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                              const SizedBox(width: 10),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cartCount == 0 ? 'My cart' : '$cartCount ${cartCount == 1 ? 'item' : 'items'}',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '₹${cartTotal.toStringAsFixed(0)}',
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 2),
                  itemBuilder: (context, i) {
                    final c = categories[i];
                    return TextButton(
                      onPressed: () => onCategoryTap(c),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textBody,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      child: Text(c.name),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _link(String label, IconData icon, VoidCallback onTap, bool active, bool compact) {
    if (compact) {
      return IconButton(
        tooltip: label,
        onPressed: onTap,
        icon: Icon(icon, color: active ? AppColors.primary : AppColors.textPrimary),
      );
    }
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: active ? AppColors.primary : AppColors.textPrimary),
      label: Text(
        label,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: active ? AppColors.primary : AppColors.textPrimary),
      ),
    );
  }
}

/// Dark green desktop footer.
class DesktopFooter extends StatelessWidget {
  final VoidCallback? onSupportTap;
  final VoidCallback? onAboutTap;

  const DesktopFooter({super.key, this.onSupportTap, this.onAboutTap});

  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(color: Color(0xFFD9E5DD), fontSize: 13);
    return Container(
      color: const Color(0xFF0B2818),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Wrap(
              spacing: 32,
              runSpacing: 24,
              alignment: WrapAlignment.spaceBetween,
              children: [
                const SizedBox(
                  width: 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('quick basket', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      SizedBox(height: 6),
                      Text(
                        'Groceries & essentials in 10–15 minutes across Koramangala, HSR Layout and BTM Layout.',
                        style: linkStyle,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Company', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 6),
                    InkWell(onTap: onAboutTap, child: const Text('About', style: linkStyle)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Help', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 6),
                    InkWell(onTap: onSupportTap, child: const Text('24/7 Support', style: linkStyle)),
                    const SizedBox(height: 6),
                    InkWell(onTap: onAboutTap, child: const Text('Terms & Privacy', style: linkStyle)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
