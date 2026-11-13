import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/category_model.dart';
import '../../../models/product_model.dart';
import '../../../services/mock_data_service.dart';
import '../../../services/supabase_service.dart';
import '../../../shared_widgets/responsive_wrapper.dart';

/// Store Inventory & Product Management Screen (PRD Section 6)
class AdminInventoryScreen extends StatefulWidget {
  const AdminInventoryScreen({super.key});

  @override
  State<AdminInventoryScreen> createState() => _AdminInventoryScreenState();
}

class _AdminInventoryScreenState extends State<AdminInventoryScreen> {
  String _searchQuery = '';
  String? _selectedCategory;
  List<ProductModel> _products = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    setState(() {
      _products = List.from(MockDataService.products);
    });
  }

  List<ProductModel> get _filteredProducts {
    return _products.where((prod) {
      final matchesSearch = _searchQuery.isEmpty ||
          prod.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          prod.brand.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == null || prod.categoryId == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> _adjustStock(ProductModel product, ProductVariant variant, int delta) async {
    final newStock = (variant.stockQuantity + delta).clamp(0, 9999);
    await SupabaseService().updateProductStock(product.id, variant.id, newStock);
    _loadProducts();
  }

  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController(text: 'Quick Basket');
    final unitCtrl = TextEditingController(text: '500 g');
    final mrpCtrl = TextEditingController(text: '60');
    final priceCtrl = TextEditingController(text: '48');
    final stockCtrl = TextEditingController(text: '50');
    final descCtrl = TextEditingController();
    final imgCtrl = TextEditingController();
    String categoryId = MockDataService.categories.isNotEmpty ? MockDataService.categories.first.id : 'cat-1';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Product to Store', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: categoryId,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: MockDataService.categories.map((c) {
                      return DropdownMenuItem(value: c.id, child: Text(c.name));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => categoryId = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  const Text('Product Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Fresh Red Onions',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Brand', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: brandCtrl,
                              decoration: InputDecoration(
                                hintText: 'Brand name',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Unit / Pack', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: unitCtrl,
                              decoration: InputDecoration(
                                hintText: 'e.g. 1 kg / 500 ml',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('MRP (₹)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: mrpCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Selling Price (₹)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: priceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Initial Stock', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: stockCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text('Image URL (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: imgCtrl,
                    decoration: InputDecoration(
                      hintText: 'https://...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      setDialogState(() => isSaving = true);
                      await SupabaseService().createProduct(
                        name: nameCtrl.text.trim(),
                        brand: brandCtrl.text.trim(),
                        categoryId: categoryId,
                        description: descCtrl.text.trim().isEmpty ? nameCtrl.text.trim() : descCtrl.text.trim(),
                        imageUrl: imgCtrl.text.trim(),
                        mrp: double.tryParse(mrpCtrl.text) ?? 60.0,
                        sellingPrice: double.tryParse(priceCtrl.text) ?? 50.0,
                        unit: unitCtrl.text.trim(),
                        stockQuantity: int.tryParse(stockCtrl.text) ?? 50,
                      );
                      Navigator.pop(ctx);
                      _loadProducts();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('🎉 Added ${nameCtrl.text} to store inventory!')),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C8340),
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('ADD PRODUCT', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF064E26),
        foregroundColor: Colors.white,
        title: const Text('Store Inventory & Products', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadProducts,
            tooltip: 'Reload Inventory',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProductDialog,
        backgroundColor: const Color(0xFF0C8340),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ResponsiveWrapper(
        maxWidth: 1200,
        child: Column(
          children: [
            // Search and Category Filter Bar
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search products by name or brand...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        FilterChip(
                          label: const Text('All Categories'),
                          selected: _selectedCategory == null,
                          onSelected: (_) => setState(() => _selectedCategory = null),
                          selectedColor: const Color(0xFF0C8340).withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: _selectedCategory == null ? const Color(0xFF0C8340) : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ...MockDataService.categories.map((cat) {
                          final isSel = _selectedCategory == cat.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(cat.name),
                              selected: isSel,
                              onSelected: (_) => setState(() => _selectedCategory = cat.id),
                              selectedColor: const Color(0xFF0C8340).withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: isSel ? const Color(0xFF0C8340) : AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Products List
            Expanded(
              child: _filteredProducts.isEmpty
                  ? const Center(child: Text('No products found matching query.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredProducts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        final variant = product.defaultVariant;
                        final isLowStock = variant.stockQuantity <= 10;
                        final isOut = variant.stockQuantity <= 0;

                        return Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    product.imageUrl,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 56,
                                      height: 56,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.shopping_bag_outlined),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${product.brand} • ${variant.unit}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            '₹${variant.sellingPrice.toStringAsFixed(0)}',
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0C8340)),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '₹${variant.mrp.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              decoration: TextDecoration.lineThrough,
                                              fontSize: 12,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Stock Controls
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isOut
                                            ? Colors.red.shade50
                                            : isLowStock
                                                ? Colors.orange.shade50
                                                : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isOut
                                            ? 'OUT OF STOCK'
                                            : isLowStock
                                                ? 'LOW STOCK (${variant.stockQuantity})'
                                                : '${variant.stockQuantity} in stock',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: isOut
                                            ? Colors.red.shade800
                                            : isLowStock
                                                ? Colors.orange.shade800
                                                : Colors.green.shade800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.grey),
                                          onPressed: () => _adjustStock(product, variant, -5),
                                          tooltip: '-5 Stock',
                                        ),
                                        Text(
                                          '${variant.stockQuantity}',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF0C8340)),
                                          onPressed: () => _adjustStock(product, variant, 10),
                                          tooltip: '+10 Stock',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
