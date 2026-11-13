import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/category_model.dart';
import '../../../models/product_model.dart';
import '../../../models/cart_item_model.dart';
import '../../../services/supabase_service.dart';
import '../../../shared_widgets/product_card.dart';
import '../../../shared_widgets/product_details_sheet.dart';
import '../../../shared_widgets/responsive_wrapper.dart';
import 'search_screen.dart';

/// Category Products & Subcategories Screen conforming to PRD Section 4.4 & 4.5
class CategoryProductsScreen extends StatefulWidget {
  final CategoryModel category;
  final List<ProductModel> allProducts;
  final Map<String, CartItemModel> cart;
  final Function(ProductModel, ProductVariant) onAddToCart;
  final Function(String productId) onIncrement;
  final Function(String productId) onDecrement;
  final VoidCallback onViewCart;

  const CategoryProductsScreen({
    super.key,
    required this.category,
    required this.allProducts,
    required this.cart,
    required this.onAddToCart,
    required this.onIncrement,
    required this.onDecrement,
    required this.onViewCart,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  String _selectedSubcategory = 'All';
  String _sortBy = 'Popularity'; // 'Popularity', 'Price: Low to High', 'Price: High to Low'
  List<String> _dynamicSubcategories = [];

  @override
  void initState() {
    super.initState();
    _dynamicSubcategories = List.from(widget.category.subcategories);
    _loadSubcategories();
  }

  Future<void> _loadSubcategories() async {
    final subs = await SupabaseService().getSubcategories(categoryId: widget.category.id);
    if (mounted && subs.isNotEmpty) {
      setState(() {
        _dynamicSubcategories = subs.map((s) => s.name).toList();
      });
    }
  }

  List<ProductModel> get _categoryProducts {
    // Filter by category ID
    var list = widget.allProducts.where((p) => p.categoryId == widget.category.id).toList();

    // If subcategory is selected, filter by subcategory keyword in name or description
    if (_selectedSubcategory != 'All') {
      final subLower = _selectedSubcategory.toLowerCase();
      final filtered = list.where((p) {
        final nameLower = p.name.toLowerCase();
        final descLower = p.description.toLowerCase();
        final brandLower = p.brand.toLowerCase();
        // Match subcategory keywords
        return nameLower.contains(subLower) ||
            descLower.contains(subLower) ||
            brandLower.contains(subLower) ||
            subLower.split(' ').any((word) => word.length > 3 && (nameLower.contains(word) || descLower.contains(word)));
      }).toList();

      if (filtered.isNotEmpty) {
        list = filtered;
      }
    }

    // Sort products
    if (_sortBy == 'Price: Low to High') {
      list.sort((a, b) => a.defaultVariant.sellingPrice.compareTo(b.defaultVariant.sellingPrice));
    } else if (_sortBy == 'Price: High to Low') {
      list.sort((a, b) => b.defaultVariant.sellingPrice.compareTo(a.defaultVariant.sellingPrice));
    } else {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    }

    return list;
  }

  int _getCartQuantity(String productId) {
    return widget.cart[productId]?.quantity ?? 0;
  }

  int get _totalCartItems =>
      widget.cart.values.fold(0, (sum, item) => sum + item.quantity);

  double get _totalCartPrice =>
      widget.cart.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  @override
  Widget build(BuildContext context) {
    final products = _categoryProducts;
    final subcategories = ['All', ..._dynamicSubcategories];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.category.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${products.length} products available',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppColors.textPrimary),
            onPressed: () {
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
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, color: AppColors.textPrimary),
            tooltip: 'Sort Products',
            onSelected: (value) => setState(() => _sortBy = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Popularity', child: Text('Popularity')),
              const PopupMenuItem(value: 'Price: Low to High', child: Text('Price: Low to High')),
              const PopupMenuItem(value: 'Price: High to Low', child: Text('Price: High to Low')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ResponsiveWrapper(
          child: Column(
            children: [
              // Subcategories Filter Chips Bar (PRD 4.4)
              Container(
                color: Colors.white,
                height: 52,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: subcategories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final sub = subcategories[index];
                    final isSelected = sub == _selectedSubcategory;

                    return FilterChip(
                      label: Text(sub),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() => _selectedSubcategory = sub);
                      },
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                      backgroundColor: Colors.grey.shade100,
                      selectedColor: AppColors.primary,
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.border,
                          width: 0.8,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    );
                  },
                ),
              ),

              const Divider(height: 1, color: AppColors.border),

              // Product Grid
              Expanded(
                child: products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No products found in "$_selectedSubcategory"',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Try selecting "All" or browse other categories',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: () => setState(() => _selectedSubcategory = 'All'),
                              child: const Text('Show All Products'),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth >= 900
                              ? 4
                              : (constraints.maxWidth >= 600 ? 3 : 2);
                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            physics: const BouncingScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: 0.70,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final product = products[index];
                              return ProductCard(
                                product: product,
                                cartQuantity: _getCartQuantity(product.id),
                                onAddToCart: () => widget.onAddToCart(product, product.defaultVariant),
                                onIncrement: () => widget.onIncrement(product.id),
                                onDecrement: () => widget.onDecrement(product.id),
                                onTap: () {
                                  ProductDetailsSheet.show(
                                    context,
                                    product: product,
                                    initialQuantity: _getCartQuantity(product.id),
                                    onAddToCart: (p, v) => widget.onAddToCart(p, v),
                                    onIncrement: (p, v) => widget.onIncrement(p.id),
                                    onDecrement: (p, v) => widget.onDecrement(p.id),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
              ),

              // Floating Mini-Cart Summary Bar
              if (_totalCartItems > 0)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_totalCartItems ${_totalCartItems == 1 ? 'ITEM' : 'ITEMS'}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '₹${_totalCartPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          widget.onViewCart();
                        },
                        child: const Row(
                          children: [
                            Text(
                              'View Cart',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
