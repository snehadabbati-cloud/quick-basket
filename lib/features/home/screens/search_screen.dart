import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/product_model.dart';
import '../../../models/cart_item_model.dart';
import '../../../shared_widgets/product_card.dart';
import '../../../shared_widgets/product_details_sheet.dart';
import '../../../shared_widgets/responsive_wrapper.dart';
import '../widgets/storefront_chrome.dart';

/// Instant Search Screen conforming to PRD Section 4.7
class SearchScreen extends StatefulWidget {
  final List<ProductModel> allProducts;
  final Map<String, CartItemModel> cart;
  final Function(ProductModel, ProductVariant) onAddToCart;
  final Function(String productId) onIncrement;
  final Function(String productId) onDecrement;
  final VoidCallback onViewCart;

  const SearchScreen({
    super.key,
    required this.allProducts,
    required this.cart,
    required this.onAddToCart,
    required this.onIncrement,
    required this.onDecrement,
    required this.onViewCart,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  static const List<String> _trendingSearches = [
    'Milk',
    'Brown Bread',
    'Eggs',
    'Atta',
    'Basmati Rice',
    'Butter',
    'Chips',
    'Apples',
    'Maggi',
    'Tea',
    'Tomato Ketchup',
    'Soap',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProductModel> get _searchResults {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return [];

    return widget.allProducts.where((p) {
      final nameLower = p.name.toLowerCase();
      final brandLower = p.brand.toLowerCase();
      final descLower = p.description.toLowerCase();
      return nameLower.contains(q) || brandLower.contains(q) || descLower.contains(q);
    }).toList();
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
    final results = _searchResults;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: (val) => setState(() => _query = val),
            decoration: InputDecoration(
              hintText: 'Search "milk", "bread", "atta"...',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Content: either trending searches or search results
              Expanded(
                child: _query.isEmpty
                    ? _buildTrendingSearches()
                    : results.isEmpty
                        ? _buildNoResults()
                        : _buildResultsGrid(results),
              ),

              // Floating Mini-Cart Summary
              if (_totalCartItems > 0)
                CartFloatingBar(
                  itemCount: _totalCartItems,
                  total: _totalCartPrice,
                  subtitle: _totalCartPrice >= 199
                      ? 'Free delivery unlocked'
                      : 'Add ₹${(199 - _totalCartPrice).toStringAsFixed(0)} for free delivery',
                  onTap: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                    widget.onViewCart();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingSearches() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Row(
          children: [
            Icon(Icons.trending_up_rounded, size: 20, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Popular & Trending Searches',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: _trendingSearches.map((term) {
            return InkWell(
              onTap: () {
                _searchController.text = term;
                setState(() => _query = term);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      term,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No products matching "$_query"',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Check spelling or search for common grocery items',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsGrid(List<ProductModel> results) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Found ${results.length} results for "$_query"',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisExtent: 262,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final product = results[index];
              return ProductCard(
                product: product,
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
            },
          ),
        ),
      ],
    );
  }
}
