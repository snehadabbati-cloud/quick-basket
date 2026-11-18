import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/category_model.dart';
import '../../../models/product_model.dart';
import '../../../models/cart_item_model.dart';
import '../../../services/supabase_service.dart';
import '../../../shared_widgets/product_card.dart';
import '../../../shared_widgets/product_details_sheet.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../widgets/storefront_chrome.dart';
import 'search_screen.dart';

/// Category Products & Subcategories Screen conforming to PRD Section 4.4 & 4.5
///
/// Mobile: subcategory rail on the left, 2-column product grid, filter chips
/// and a floating cart bar. Desktop: storefront header, subcategory sidebar,
/// product grid and a sticky checkout bar.
class CategoryProductsScreen extends StatefulWidget {
  final CategoryModel category;
  final List<ProductModel> allProducts;
  final Map<String, CartItemModel> cart;
  final Function(ProductModel, ProductVariant) onAddToCart;
  final Function(String productId) onIncrement;
  final Function(String productId) onDecrement;
  final VoidCallback onViewCart;
  final List<CategoryModel> allCategories;
  final String addressLine;
  final ValueChanged<int>? onNavigateTab;

  const CategoryProductsScreen({
    super.key,
    required this.category,
    required this.allProducts,
    required this.cart,
    required this.onAddToCart,
    required this.onIncrement,
    required this.onDecrement,
    required this.onViewCart,
    this.allCategories = const [],
    this.addressLine = 'Home · Green Valley, Block B',
    this.onNavigateTab,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  static const _sortOptions = ['Popularity', 'Price: Low to High', 'Price: High to Low', 'Discount'];

  late CategoryModel _category;
  String _selectedSubcategory = 'All';
  String _sortBy = 'Popularity';
  bool _offersOnly = false;
  bool _under50 = false;
  List<String> _dynamicSubcategories = [];
  List<ProductModel> _products = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _dynamicSubcategories = List.from(_category.subcategories);
    _products = List.from(widget.allProducts);
    _loadSubcategories();
    SupabaseService().inventoryNotifier.addListener(_onInventoryChanged);
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (mounted) {
        SupabaseService().checkStockOverridesChanged();
      }
    });
  }

  void _onInventoryChanged() async {
    final updated = await SupabaseService().getProducts();
    if (mounted) {
      setState(() => _products = updated);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    SupabaseService().inventoryNotifier.removeListener(_onInventoryChanged);
    super.dispose();
  }

  Future<void> _loadSubcategories() async {
    final subs = await SupabaseService().getSubcategories(categoryId: _category.id);
    if (mounted && subs.isNotEmpty) {
      setState(() {
        _dynamicSubcategories = subs.where((s) => s.isActive).map((s) => s.name).toList();
      });
    }
  }

  void _switchCategory(CategoryModel category) {
    setState(() {
      _category = category;
      _selectedSubcategory = 'All';
      _dynamicSubcategories = List.from(category.subcategories);
    });
    _loadSubcategories();
  }

  bool _matchesSub(ProductModel p, String sub) {
    if (sub == 'All') return true;
    final subLower = sub.toLowerCase();
    final nameLower = p.name.toLowerCase();
    final descLower = p.description.toLowerCase();
    final brandLower = p.brand.toLowerCase();
    return nameLower.contains(subLower) ||
        descLower.contains(subLower) ||
        brandLower.contains(subLower) ||
        subLower.split(' ').any((word) => word.length > 3 && (nameLower.contains(word) || descLower.contains(word)));
  }

  List<ProductModel> get _baseProducts => _products.where((p) => p.categoryId == _category.id).toList();

  int _countFor(String sub) {
    final base = _baseProducts;
    if (sub == 'All') return base.length;
    final matched = base.where((p) => _matchesSub(p, sub)).length;
    return matched == 0 ? base.length : matched;
  }

  List<ProductModel> get _categoryProducts {
    var list = _baseProducts;

    // If subcategory is selected, filter by subcategory keyword in name or description
    if (_selectedSubcategory != 'All') {
      final filtered = list.where((p) => _matchesSub(p, _selectedSubcategory)).toList();
      if (filtered.isNotEmpty) list = filtered;
    }

    if (_offersOnly) list = list.where((p) => p.defaultVariant.discountPercentage > 0).toList();
    if (_under50) list = list.where((p) => p.defaultVariant.sellingPrice < 50).toList();

    // Sort products
    if (_sortBy == 'Price: Low to High') {
      list.sort((a, b) => a.defaultVariant.sellingPrice.compareTo(b.defaultVariant.sellingPrice));
    } else if (_sortBy == 'Price: High to Low') {
      list.sort((a, b) => b.defaultVariant.sellingPrice.compareTo(a.defaultVariant.sellingPrice));
    } else if (_sortBy == 'Discount') {
      list.sort((a, b) => b.defaultVariant.discountPercentage.compareTo(a.defaultVariant.discountPercentage));
    } else {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    }

    return list;
  }

  int _getCartQuantity(String productId) => widget.cart[productId]?.quantity ?? 0;

  int get _totalCartItems => widget.cart.values.fold(0, (sum, item) => sum + item.quantity);

  double get _totalCartPrice => widget.cart.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  void _viewCart() {
    Navigator.pop(context);
    widget.onViewCart();
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          allProducts: widget.allProducts,
          cart: widget.cart,
          onAddToCart: widget.onAddToCart,
          onIncrement: widget.onIncrement,
          onDecrement: widget.onDecrement,
          onViewCart: widget.onViewCart,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  Widget _productCard(ProductModel product, {bool large = false}) {
    return ProductCard(
      product: product,
      large: large,
      cartQuantity: _getCartQuantity(product.id),
      onAddToCart: () => setState(() => widget.onAddToCart(product, product.defaultVariant)),
      onIncrement: () => setState(() => widget.onIncrement(product.id)),
      onDecrement: () => setState(() => widget.onDecrement(product.id)),
      onTap: () {
        ProductDetailsSheet.show(
          context,
          product: product,
          initialQuantity: _getCartQuantity(product.id),
          onAddToCart: (p, v) => widget.onAddToCart(p, v),
          onIncrement: (p, v) => widget.onIncrement(p.id),
          onDecrement: (p, v) => widget.onDecrement(p.id),
        ).then((_) => setState(() {}));
      },
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Sort by', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _sortBy,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _sortBy = v);
                  Navigator.pop(ctx);
                },
                child: Column(
                  children: _sortOptions
                      .map((o) => RadioListTile<String>(
                            value: o,
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.primary,
                            title: Text(o, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Offers only', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Products with a discount'),
                  value: _offersOnly,
                  onChanged: (v) {
                    setState(() => _offersOnly = v);
                    setSheet(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Under ₹50', style: TextStyle(fontWeight: FontWeight.w700)),
                  value: _under50,
                  onChanged: (v) {
                    setState(() => _under50 = v);
                    setSheet(() {});
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('Show results'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    IconData? leading,
    IconData? trailing,
  }) {
    return Material(
      color: selected ? AppColors.primaryLight : Colors.white,
      shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.primary : AppColors.borderStrong)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[Icon(leading, size: 15, color: selected ? AppColors.primary : AppColors.textPrimary), const SizedBox(width: 4)],
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? AppColors.primary : AppColors.textPrimary),
              ),
              if (trailing != null) ...[const SizedBox(width: 2), Icon(trailing, size: 16)],
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyProducts() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text('No products found in "$_selectedSubcategory"',
                textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Try "All" or clear your filters', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => setState(() {
                _selectedSubcategory = 'All';
                _offersOnly = false;
                _under50 = false;
              }),
              child: const Text('Show all products'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Responsive.isDesktop(context) ? _buildDesktop() : _buildMobile();
  }

  // ------------------------------- Mobile -----------------------------------

  Widget _buildMobile() {
    final products = _categoryProducts;
    final subcategories = ['All', ..._dynamicSubcategories];
    final visual = CategoryVisual.of(_category);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Stack(
              children: [
                Column(
                  children: [
                    Container(
                      height: 64,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Back',
                            icon: const Icon(Icons.chevron_left_rounded, size: 28),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_category.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                Text('$_selectedSubcategory · ${products.length} items',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          IconButton(tooltip: 'Search in category', icon: const Icon(Icons.search_rounded), onPressed: _openSearch),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 86,
                            decoration: const BoxDecoration(
                              color: AppColors.background,
                              border: Border(right: BorderSide(color: AppColors.border)),
                            ),
                            child: ListView.builder(
                              padding: const EdgeInsets.only(top: 6, bottom: 120),
                              itemCount: subcategories.length,
                              itemBuilder: (context, i) {
                                final sub = subcategories[i];
                                final on = sub == _selectedSubcategory;
                                return Material(
                                  color: on ? Colors.white : Colors.transparent,
                                  child: InkWell(
                                    onTap: () => setState(() => _selectedSubcategory = sub),
                                    child: Stack(
                                      children: [
                                        if (on)
                                          Positioned(
                                            right: 0,
                                            top: 10,
                                            bottom: 10,
                                            child: Container(
                                              width: 4,
                                              decoration: const BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                                              ),
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                          child: Column(
                                            children: [
                                              Container(
                                                width: 52,
                                                height: 52,
                                                decoration: BoxDecoration(
                                                  color: on ? const Color(0xFFD4EEDC) : const Color(0xFFEAF1EC),
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                child: Icon(visual.icon, color: visual.ink, size: 26),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                sub,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  height: 1.25,
                                                  fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                                                  color: on ? AppColors.primary : AppColors.textBody,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _chip(
                                        label: 'Filters',
                                        leading: Icons.tune_rounded,
                                        selected: _under50,
                                        onTap: _showFilterSheet,
                                      ),
                                      _chip(
                                        label: _sortBy == 'Popularity' ? 'Sort' : _sortBy,
                                        trailing: Icons.keyboard_arrow_down_rounded,
                                        selected: _sortBy != 'Popularity',
                                        onTap: _showSortSheet,
                                      ),
                                      _chip(
                                        label: 'Offers',
                                        selected: _offersOnly,
                                        onTap: () => setState(() => _offersOnly = !_offersOnly),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: products.isEmpty
                                      ? _emptyProducts()
                                      : LayoutBuilder(
                                          builder: (context, constraints) {
                                            final cols = constraints.maxWidth >= 560 ? 3 : 2;
                                            return GridView.builder(
                                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
                                              itemCount: products.length,
                                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: cols,
                                                crossAxisSpacing: 10,
                                                mainAxisSpacing: 10,
                                                mainAxisExtent: 262,
                                              ),
                                              itemBuilder: (context, i) => _productCard(products[i]),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_totalCartItems > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 10,
                    child: CartFloatingBar(
                      itemCount: _totalCartItems,
                      total: _totalCartPrice,
                      subtitle: _totalCartPrice >= 199
                          ? 'Free delivery unlocked'
                          : 'Add ₹${(199 - _totalCartPrice).toStringAsFixed(0)} for free delivery',
                      onTap: _viewCart,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------- Desktop ----------------------------------

  void _navigateTab(int tab) {
    Navigator.pop(context);
    widget.onNavigateTab?.call(tab);
  }

  Widget _buildDesktop() {
    final products = _categoryProducts;
    final subcategories = ['All', ..._dynamicSubcategories];
    final visual = CategoryVisual.of(_category);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          DesktopShopHeader(
            addressLine: widget.addressLine,
            onAddressTap: () => _navigateTab(4),
            onSearchTap: _openSearch,
            onLogoTap: () => _navigateTab(0),
            onOrdersTap: () => _navigateTab(3),
            onAccountTap: () => _navigateTab(4),
            onCartTap: _viewCart,
            cartCount: _totalCartItems,
            cartTotal: _totalCartPrice,
            categories: widget.allCategories,
            onCategoryTap: _switchCategory,
            activeTab: -1,
          ),
          Expanded(
            child: ListView(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 20, 32, 48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              InkWell(
                                onTap: () => _navigateTab(0),
                                child: const Text('Home', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                              ),
                              Text(' / ${_category.name} / ', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              Text(_selectedSubcategory, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 250,
                                padding: const EdgeInsets.all(10),
                                decoration: qbCard(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                      child: Text(
                                        _category.name.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.7,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    for (final sub in subcategories)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Material(
                                          color: sub == _selectedSubcategory ? AppColors.primaryLight : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(12),
                                            onTap: () => setState(() => _selectedSubcategory = sub),
                                            child: SizedBox(
                                              height: 52,
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 36,
                                                      height: 36,
                                                      decoration: BoxDecoration(
                                                        color: sub == _selectedSubcategory ? Colors.white : AppColors.surfaceMuted,
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: Icon(visual.icon, size: 20, color: visual.ink),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        sub,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: sub == _selectedSubcategory ? FontWeight.w800 : FontWeight.w600,
                                                          color: sub == _selectedSubcategory ? AppColors.primaryDeep : AppColors.textBody,
                                                        ),
                                                      ),
                                                    ),
                                                    Text('${_countFor(sub)}',
                                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _selectedSubcategory == 'All' ? _category.name : _selectedSubcategory,
                                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                                              ),
                                              Text('${products.length} items · delivered in 12 minutes',
                                                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                                            ],
                                          ),
                                        ),
                                        _chip(
                                          label: 'Offers',
                                          selected: _offersOnly,
                                          onTap: () => setState(() => _offersOnly = !_offersOnly),
                                        ),
                                        const SizedBox(width: 8),
                                        _chip(
                                          label: 'Under ₹50',
                                          selected: _under50,
                                          onTap: () => setState(() => _under50 = !_under50),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          height: 38,
                                          padding: const EdgeInsets.only(left: 14, right: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(color: AppColors.borderStrong),
                                          ),
                                          child: Row(
                                            children: [
                                              const Text('Sort', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                              const SizedBox(width: 6),
                                              DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: _sortBy,
                                                  borderRadius: BorderRadius.circular(12),
                                                  style: const TextStyle(
                                                      fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                                  items: _sortOptions
                                                      .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                                                      .toList(),
                                                  onChanged: (v) => setState(() => _sortBy = v ?? _sortBy),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    if (products.isEmpty)
                                      SizedBox(height: 360, child: _emptyProducts())
                                    else
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: products.length,
                                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 230,
                                          mainAxisExtent: 340,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 16,
                                        ),
                                        itemBuilder: (context, i) => _productCard(products[i], large: true),
                                      ),
                                  ],
                                ),
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
          if (_totalCartItems > 0)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF102818).withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -8)),
                ],
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                text: '$_totalCartItems items · ₹${_totalCartPrice.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const TextSpan(text: ' · Free delivery above ₹199', style: TextStyle(color: AppColors.textSecondary)),
                            ]),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _viewCart,
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(Icons.chevron_right_rounded),
                          label: const Text('Go to checkout', style: TextStyle(fontSize: 15)),
                          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 22)),
                        ),
                      ],
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
