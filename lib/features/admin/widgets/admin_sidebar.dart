import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared_widgets/qb_ui.dart';

/// Admin pages reachable from the sidebar.
enum AdminSection { dashboard, orders, reports, products, categories, inventory, customers, deliveryPartners, settings }

extension AdminSectionInfo on AdminSection {
  String get label {
    switch (this) {
      case AdminSection.dashboard:
        return 'Dashboard';
      case AdminSection.orders:
        return 'Live Orders';
      case AdminSection.reports:
        return 'Reports';
      case AdminSection.products:
        return 'Products';
      case AdminSection.categories:
        return 'Categories';
      case AdminSection.inventory:
        return 'Inventory';
      case AdminSection.customers:
        return 'Customers';
      case AdminSection.deliveryPartners:
        return 'Delivery Partners';
      case AdminSection.settings:
        return 'Settings';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminSection.dashboard:
        return Icons.space_dashboard_outlined;
      case AdminSection.orders:
        return Icons.receipt_long_outlined;
      case AdminSection.reports:
        return Icons.insights_outlined;
      case AdminSection.products:
        return Icons.inventory_2_outlined;
      case AdminSection.categories:
        return Icons.grid_view_outlined;
      case AdminSection.inventory:
        return Icons.warehouse_outlined;
      case AdminSection.customers:
        return Icons.people_outline_rounded;
      case AdminSection.deliveryPartners:
        return Icons.delivery_dining_rounded;
      case AdminSection.settings:
        return Icons.settings_outlined;
    }
  }
}

/// Collapsible admin sidebar: brand, store status, grouped navigation with
/// live badges and the signed-in manager.
class AdminSidebar extends StatelessWidget {
  final AdminSection selected;
  final ValueChanged<AdminSection> onSelect;
  final bool collapsed;
  final VoidCallback? onToggleCollapse;
  final int newOrders;
  final int lowStock;
  final String managerName;
  final String managerEmail;
  final bool storeOpen;
  final VoidCallback onLogout;
  final VoidCallback onOpenCustomerApp;

  const AdminSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.collapsed,
    this.onToggleCollapse,
    required this.newOrders,
    required this.lowStock,
    required this.managerName,
    required this.managerEmail,
    required this.storeOpen,
    required this.onLogout,
    required this.onOpenCustomerApp,
  });

  static const _groups = [
    ('OVERVIEW', [AdminSection.dashboard, AdminSection.orders, AdminSection.reports]),
    ('CATALOG', [AdminSection.products, AdminSection.categories, AdminSection.inventory]),
    ('PEOPLE', [AdminSection.customers, AdminSection.deliveryPartners]),
    ('SYSTEM', [AdminSection.settings]),
  ];

  @override
  Widget build(BuildContext context) {
    final open = !collapsed;
    final initials = managerName.split(' ').where((s) => s.isNotEmpty).take(2).map((s) => s[0].toUpperCase()).join();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: open ? 248 : 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(open ? 14 : 8, 18, open ? 14 : 8, 0),
              child: Flex(
                direction: open ? Axis.horizontal : Axis.vertical,
                mainAxisAlignment: open ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
                mainAxisSize: open ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Flexible(
                    child: InkWell(
                      onTap: () => onSelect(AdminSection.dashboard),
                      borderRadius: BorderRadius.circular(12),
                      child: QbLogo(size: 40, showText: open, caption: open ? 'STORE ADMIN' : null),
                    ),
                  ),
                  if (open) const SizedBox(width: 8) else const SizedBox(height: 10),
                  if (onToggleCollapse != null)
                    IconButton.outlined(
                      tooltip: open ? 'Collapse sidebar' : 'Expand sidebar',
                      onPressed: onToggleCollapse,
                      style: IconButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                      ),
                      icon: Icon(open ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, size: 18),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (open)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAF8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: storeOpen ? AppColors.primary : AppColors.error,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: (storeOpen ? AppColors.primary : AppColors.error).withValues(alpha: 0.2), spreadRadius: 4)],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nizampet Dark Store (500090)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text(
                            storeOpen ? 'Open · 7 AM – 11 PM' : 'Closed · not accepting orders',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(open ? 14 : 12, 12, open ? 14 : 12, 12),
                children: [
                  for (final g in _groups) ...[
                    if (open)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                        child: Text(
                          g.$1,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.textSecondary),
                        ),
                      )
                    else
                      const SizedBox(height: 10),
                    for (final s in g.$2) _item(s, open),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: open ? 14 : 12),
              child: _plainItem(Icons.storefront_outlined, 'Customer App', open, onOpenCustomerApp),
            ),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: EdgeInsets.fromLTRB(open ? 14 : 8, 14, open ? 8 : 8, 16),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(
                mainAxisAlignment: open ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  Tooltip(
                    message: managerName,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(initials.isEmpty ? 'SM' : initials,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryDeep)),
                    ),
                  ),
                  if (open) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(managerName, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text(managerEmail, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Log out',
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(AdminSection s, bool open) {
    final on = s == selected;
    final badge = s == AdminSection.orders && newOrders > 0
        ? (newOrders, AppColors.primary, Colors.white)
        : s == AdminSection.inventory && lowStock > 0
            ? (lowStock, AppColors.accent, AppColors.textPrimary)
            : null;

    final tile = Material(
      color: on ? AppColors.primaryLight : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => onSelect(s),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 44,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: open ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    Icon(s.icon, size: 20, color: on ? AppColors.primaryDeep : AppColors.textBody),
                    if (open) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                            color: on ? AppColors.primaryDeep : AppColors.textBody,
                          ),
                        ),
                      ),
                      if (badge != null) _badge(badge),
                    ],
                  ],
                ),
              ),
              if (!open && badge != null) Positioned(top: 3, right: 3, child: _badge(badge)),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: open ? tile : Tooltip(message: s.label, child: tile),
    );
  }

  Widget _plainItem(IconData icon, String label, bool open, VoidCallback onTap) {
    final tile = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: open ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppColors.textBody),
              if (open) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textBody),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return open ? tile : Tooltip(message: label, child: tile);
  }

  Widget _badge((int, Color, Color) b) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: b.$2, borderRadius: BorderRadius.circular(999)),
      child: Text('${b.$1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: b.$3)),
    );
  }
}
