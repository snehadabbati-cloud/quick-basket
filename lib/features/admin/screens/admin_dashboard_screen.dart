import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../models/product_model.dart';
import '../../../services/mock_data_service.dart';
import '../../../services/supabase_service.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../pages/admin_customers_page.dart';
import '../pages/admin_orders_board.dart';
import '../pages/admin_overview_page.dart';
import '../pages/admin_products_page.dart';
import '../pages/admin_reports_page.dart';
import '../pages/admin_settings_page.dart';
import '../widgets/admin_order_details_dialog.dart';
import '../widgets/admin_orders_logic.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/admin_ui.dart';
import 'admin_categories_screen.dart';
import 'admin_inventory_screen.dart';
import 'admin_login_screen.dart';

/// Dark Store Operations Command Center conforming to PRD Section 6
///
/// Admin shell: collapsible sidebar + top bar hosting every admin page.
/// Holds the shared live order state (realtime notifier + polling) and the
/// order status pipeline with undo.
class AdminDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> managerData;
  final AdminSection initialSection;

  const AdminDashboardScreen({
    super.key,
    required this.managerData,
    this.initialSection = AdminSection.dashboard,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AdminSection _section = widget.initialSection;
  bool _collapsed = false;
  bool _storeOpen = true;

  List<OrderModel> _orders = [];
  bool _isLoading = true;
  Timer? _pollingTimer;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();
  AdminOrderAction? _lastAction;
  final Map<String, String> _customerNames = {};

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    // 1. Subscribe to reactive order events (instant local updates)
    SupabaseService().ordersNotifier.addListener(_onOrdersNotifierChanged);
    // 2. Fallback polling for remote database syncing (1s for instant cross-tab order state)
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) => _fetchOrders(silent: true));
  }

  @override
  void dispose() {
    SupabaseService().ordersNotifier.removeListener(_onOrdersNotifierChanged);
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onOrdersNotifierChanged() {
    if (mounted) {
      setState(() {
        _orders = List.from(SupabaseService().localOrders);
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchOrders({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    final orders = await SupabaseService().getAllStoreOrders();
    if (mounted) {
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
      _resolveCustomerNames(orders);
    }
  }

  Future<void> _resolveCustomerNames(List<OrderModel> orders) async {
    final ids = orders.map((o) => o.userId).toSet().where((id) => !_customerNames.containsKey(id)).toList();
    for (final id in ids) {
      _customerNames[id] = _fallbackName(id);
      if (id.isEmpty || id.startsWith('00000000')) continue;
      try {
        final profile = await SupabaseService().getProfile(id);
        final name = profile?['full_name'] as String?;
        if (name != null && name.trim().isNotEmpty && mounted) {
          setState(() => _customerNames[id] = name.trim());
        }
      } catch (_) {}
    }
  }

  String _fallbackName(String userId) {
    if (userId.isEmpty || userId.startsWith('00000000') || userId == 'guest-user') return 'Guest customer';
    final clean = userId.replaceAll('-', '');
    return 'Customer ${clean.substring(0, clean.length < 4 ? clean.length : 4).toUpperCase()}';
  }

  String _customerName(OrderModel o) => _customerNames[o.userId] ?? _fallbackName(o.userId);

  // ---------------------------------------------------------------------------
  // Order pipeline
  // ---------------------------------------------------------------------------

  Future<void> _setStatus(OrderModel order, OrderStatus to, {String? reason}) async {
    final from = order.status;
    await SupabaseService().updateOrderStatus(order.id, to, cancellationReason: reason);
    if (to == OrderStatus.cancelled) {
      await SupabaseService().restoreOrderStock(order);
    }
    if (!mounted) return;
    setState(() {
      _lastAction = AdminOrderAction(
        orderId: order.id,
        orderNumber: order.orderNumber,
        customer: _customerName(order),
        from: from,
        to: to,
      );
    });
    _fetchOrders(silent: true);
  }

  Future<void> _advanceOrder(OrderModel order) async {
    final next = OrderFlow.next(order.status);
    if (next == null) return;
    if (next == OrderStatus.delivered) {
      final ok = await showDeliveryOtpDialog(context, order);
      if (!ok) return;
    }
    await _setStatus(order, next);
  }

  Future<void> _rejectOrder(OrderModel order) => _setStatus(order, OrderStatus.cancelled, reason: 'Cancelled by store');

  Future<void> _undoLastAction() async {
    final action = _lastAction;
    if (action == null) return;
    await SupabaseService().updateOrderStatus(action.orderId, action.from);
    if (!mounted) return;
    setState(() => _lastAction = null);
    _fetchOrders(silent: true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Undone — ${action.orderNumber} is back in ${OrderFlow.stageTitle(action.from)}')),
    );
  }

  void _openOrderDetails(OrderModel order) {
    AdminOrderDetailsDialog.show(context, order: order, onOrderUpdated: () => _fetchOrders(silent: true));
  }

  Future<void> _restock(ProductModel product, ProductVariant variant) async {
    await SupabaseService().updateProductStock(product.id, variant.id, variant.stockQuantity + 20);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Restocked ${product.name} (+20 units)')),
    );
  }

  // ---------------------------------------------------------------------------

  int get _newOrders => _orders.where((o) => o.status == OrderStatus.placed).length;

  int get _lowStock => MockDataService.products
      .expand((p) => p.variants)
      .where((v) => v.stockQuantity < 15)
      .length;

  void _select(AdminSection s) {
    setState(() => _section = s);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) Navigator.pop(context);
  }

  Future<void> _logout() async {
    await SupabaseService().signOut();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
    }
  }

  void _openCustomerApp() => Navigator.pushReplacementNamed(context, '/');

  AdminSidebar _sidebar({required bool collapsible}) {
    return AdminSidebar(
      selected: _section,
      onSelect: _select,
      collapsed: collapsible && _collapsed,
      onToggleCollapse: collapsible ? () => setState(() => _collapsed = !_collapsed) : null,
      newOrders: _newOrders,
      lowStock: _lowStock,
      managerName: (widget.managerData['name'] as String?) ?? 'Store Manager',
      managerEmail: (widget.managerData['email'] as String?) ?? 'manager@quickbasket.com',
      storeOpen: _storeOpen,
      onLogout: _logout,
      onOpenCustomerApp: _openCustomerApp,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = Responsive.width(context) >= 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.adminBackground,
      drawer: wide ? null : Drawer(width: 260, child: _sidebar(collapsible: false)),
      body: Row(
        children: [
          if (wide) _sidebar(collapsible: true),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(wide),
                Expanded(child: _buildPage()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool wide) {
    final name = (widget.managerData['name'] as String?) ?? 'Store Manager';
    final initials = name.split(' ').where((s) => s.isNotEmpty).take(2).map((s) => s[0].toUpperCase()).join();
    final compact = Responsive.width(context) < 640;

    return Container(
      height: 68,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (!wide) ...[
            IconButton(
              tooltip: 'Open menu',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SizedBox(
                  height: 42,
                  child: AdminSearchField(
                    controller: _searchController,
                    hint: compact ? 'Search orders…' : 'Search orders by #, customer, item or address…',
                    onChanged: (v) {
                      setState(() {
                        _search = v;
                        if (v.isNotEmpty && _section != AdminSection.orders) _section = AdminSection.orders;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (!compact)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(999)),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.18), spreadRadius: 4)],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Live · Realtime sync on',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDeep)),
                ],
              ),
            ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: 'Refresh orders',
            onPressed: () => _fetchOrders(),
            style: IconButton.styleFrom(side: const BorderSide(color: AppColors.border)),
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
          const SizedBox(width: 8),
          Badge(
            isLabelVisible: _newOrders > 0,
            label: Text('$_newOrders'),
            backgroundColor: const Color(0xFFE5484D),
            child: IconButton.outlined(
              tooltip: _newOrders > 0 ? '$_newOrders new orders' : 'Notifications',
              onPressed: () => _select(AdminSection.orders),
              style: IconButton.styleFrom(side: const BorderSide(color: AppColors.border)),
              icon: const Icon(Icons.notifications_none_rounded, size: 20),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 14),
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(initials.isEmpty ? 'SM' : initials,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const Text('Nizampet, 500090 (Telangana)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPage() {
    switch (_section) {
      case AdminSection.dashboard:
        return AdminOverviewPage(
          orders: _orders,
          customerName: _customerName,
          onAdvance: _advanceOrder,
          onOpenSection: _select,
          onRestock: _restock,
        );
      case AdminSection.orders:
        return AdminOrdersBoard(
          orders: _orders,
          isLoading: _isLoading,
          search: _search,
          customerName: _customerName,
          lastAction: _lastAction,
          onAdvance: _advanceOrder,
          onReject: _rejectOrder,
          onUndo: _undoLastAction,
          onDismiss: () => setState(() => _lastAction = null),
          onOpenDetails: _openOrderDetails,
          onClearSearch: () {
            _searchController.clear();
            setState(() => _search = '');
          },
        );
      case AdminSection.reports:
        return AdminReportsPage(orders: _orders);
      case AdminSection.products:
        return const AdminProductsPage();
      case AdminSection.categories:
        return const AdminCategoriesScreen(embedded: true);
      case AdminSection.inventory:
        return const AdminInventoryScreen();
      case AdminSection.customers:
        return AdminCustomersPage(
          orders: _orders,
          customerName: _customerName,
          onViewOrders: (query) {
            _searchController.text = query;
            setState(() {
              _search = query;
              _section = AdminSection.orders;
            });
          },
        );
      case AdminSection.settings:
        return AdminSettingsPage(
          managerData: widget.managerData,
          storeOpen: _storeOpen,
          onStoreOpenChanged: (v) => setState(() => _storeOpen = v),
        );
    }
  }
}
