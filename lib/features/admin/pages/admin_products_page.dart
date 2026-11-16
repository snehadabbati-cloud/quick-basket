import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/category_model.dart';
import '../../../models/product_model.dart';
import '../../../models/subcategory_model.dart';
import '../../../services/mock_data_service.dart';
import '../../../services/supabase_service.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../widgets/admin_ui.dart';

/// Products catalogue: searchable table with category filter, visibility
/// toggles and an Add / Edit product panel.
class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  static const int _pageSize = 10;

  String _query = '';
  String? _categoryFilter;
  String _tab = 'all';
  int _page = 0;
  bool? _panelOpen;
  List<CategoryModel> _categories = MockDataService.categories;

  // Form state
  ProductModel? _editing;
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _mrpCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _formCategory;
  String? _formSubcategory;
  List<SubcategoryModel> _subcategories = [];
  bool _formActive = true;
  bool _saving = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    SupabaseService().hiddenProductIds.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resetForm();
      _loadCategories();
    });
  }

  @override
  void dispose() {
    SupabaseService().hiddenProductIds.removeListener(_refresh);
    for (final c in [_nameCtrl, _brandCtrl, _unitCtrl, _mrpCtrl, _priceCtrl, _stockCtrl, _skuCtrl, _imageCtrl, _descCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCategories() async {
    final cats = await SupabaseService().getAllCategories();
    if (!mounted) return;
    setState(() => _categories = cats.isEmpty ? MockDataService.categories : cats);
    if (_formCategory == null && _categories.isNotEmpty) {
      _selectFormCategory(_categories.first.id);
    }
  }

  Future<void> _selectFormCategory(String id, {String? subcategoryId}) async {
    setState(() {
      _formCategory = id;
      _formSubcategory = subcategoryId;
      _subcategories = [];
    });
    final subs = await SupabaseService().getSubcategories(categoryId: id);
    if (!mounted || _formCategory != id) return;
    setState(() {
      _subcategories = subs;
      if (_formSubcategory != null && !subs.any((s) => s.id == _formSubcategory)) _formSubcategory = null;
    });
  }

  void _resetForm() {
    setState(_clearForm);
    if (_categories.isNotEmpty) _selectFormCategory(_categories.first.id);
  }

  void _clearForm() {
    _editing = null;
    _nameCtrl.clear();
    _brandCtrl.text = 'Quick Basket';
    _unitCtrl.text = '500 g';
    _mrpCtrl.clear();
    _priceCtrl.clear();
    _stockCtrl.text = '50';
    _skuCtrl.clear();
    _imageCtrl.clear();
    _descCtrl.clear();
    _formActive = true;
    _formError = null;
  }

  void _startAdd() {
    _resetForm();
    setState(() => _panelOpen = true);
  }

  void _startEdit(ProductModel p) {
    final v = p.defaultVariant;
    setState(() {
      _editing = p;
      _nameCtrl.text = p.name;
      _brandCtrl.text = p.brand;
      _unitCtrl.text = v.unit;
      _mrpCtrl.text = v.mrp.toStringAsFixed(0);
      _priceCtrl.text = v.sellingPrice.toStringAsFixed(0);
      _stockCtrl.text = '${v.stockQuantity}';
      _skuCtrl.text = v.sku ?? '';
      _imageCtrl.text = p.imageUrl;
      _descCtrl.text = p.description;
      _formActive = SupabaseService().isProductVisible(p.id);
      _formError = null;
      _panelOpen = true;
    });
    _selectFormCategory(p.categoryId, subcategoryId: p.subcategoryId);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final mrp = double.tryParse(_mrpCtrl.text.trim());
    final price = double.tryParse(_priceCtrl.text.trim());
    final stock = int.tryParse(_stockCtrl.text.trim());
    String? error;
    if (name.isEmpty) {
      error = 'Please enter a product name';
    } else if (_formCategory == null) {
      error = 'Please choose a category';
    } else if (mrp == null || mrp <= 0) {
      error = 'Enter a valid MRP';
    } else if (price == null || price <= 0) {
      error = 'Enter a valid selling price';
    } else if (price > mrp) {
      error = 'Selling price cannot be higher than MRP';
    } else if (stock == null || stock < 0) {
      error = 'Enter a valid stock quantity';
    }
    if (error != null) {
      setState(() => _formError = error);
      return;
    }

    setState(() {
      _saving = true;
      _formError = null;
    });

    final editing = _editing;
    String productId;
    if (editing == null) {
      final created = await SupabaseService().createProduct(
        name: name,
        brand: _brandCtrl.text.trim().isEmpty ? 'Quick Basket' : _brandCtrl.text.trim(),
        categoryId: _formCategory!,
        description: _descCtrl.text.trim(),
        imageUrl: _imageCtrl.text.trim(),
        mrp: mrp!,
        sellingPrice: price!,
        unit: _unitCtrl.text.trim().isEmpty ? '1 unit' : _unitCtrl.text.trim(),
        stockQuantity: stock!,
      );
      productId = created?.id ?? '';
      final idx = MockDataService.products.indexWhere((p) => p.id == productId);
      if (idx >= 0) {
        final p = MockDataService.products[idx];
        MockDataService.products[idx] = p.copyWith(
          subcategoryId: _formSubcategory,
          variants: p.variants.isEmpty
              ? p.variants
              : [p.variants.first.copyWith(sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim())],
        );
      }
    } else {
      productId = editing.id;
      final idx = MockDataService.products.indexWhere((p) => p.id == editing.id);
      if (idx >= 0) {
        final p = MockDataService.products[idx];
        final variants = p.variants.isEmpty
            ? <ProductVariant>[]
            : [
                p.variants.first.copyWith(
                  unit: _unitCtrl.text.trim(),
                  mrp: mrp,
                  sellingPrice: price,
                  sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
                ),
                ...p.variants.skip(1),
              ];
        MockDataService.products[idx] = p.copyWith(
          name: name,
          brand: _brandCtrl.text.trim(),
          categoryId: _formCategory,
          subcategoryId: _formSubcategory,
          description: _descCtrl.text.trim(),
          imageUrl: _imageCtrl.text.trim().isEmpty ? p.imageUrl : _imageCtrl.text.trim(),
          variants: variants,
        );
        if (variants.isNotEmpty) {
          await SupabaseService().updateProductStock(p.id, variants.first.id, stock!);
        }
      }
    }
    if (productId.isNotEmpty) SupabaseService().setProductVisibility(productId, _formActive);

    if (!mounted) return;
    setState(() => _saving = false);
    _resetForm();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(editing == null ? '$name added to store inventory' : '$name updated')),
    );
  }

  String _categoryName(String id) {
    for (final c in _categories) {
      if (c.id == id) return c.name;
    }
    return '—';
  }

  List<ProductModel> get _filtered {
    final q = _query.toLowerCase();
    return MockDataService.products.where((p) {
      final visible = SupabaseService().isProductVisible(p.id);
      if (_tab == 'active' && !visible) return false;
      if (_tab == 'hidden' && visible) return false;
      if (_categoryFilter != null && p.categoryId != _categoryFilter) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.brand.toLowerCase().contains(q) ||
          p.variants.any((v) => (v.sku ?? '').toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final wide = Responsive.width(context) >= 1280;
    final panelOpen = _panelOpen ?? wide;
    final mobile = Responsive.isMobile(context);
    final items = _filtered;
    final pages = (items.length / _pageSize).ceil().clamp(1, 9999);
    final page = _page.clamp(0, pages - 1);
    final pageItems = items.skip(page * _pageSize).take(_pageSize).toList();

    final table = _buildTable(items, pageItems, page, pages);
    final panel = _buildPanel();

    return ListView(
      padding: EdgeInsets.fromLTRB(mobile ? 16 : 32, 24, mobile ? 16 : 32, 40),
      children: [
        AdminPageHeader(
          title: 'Products',
          subtitle: 'Manage what customers see in the store, with variants, pricing and stock',
          actions: [
            ElevatedButton.icon(
              onPressed: _startAdd,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add Product'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (panelOpen && wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: table), const SizedBox(width: 18), SizedBox(width: 380, child: panel)],
          )
        else ...[
          if (panelOpen) ...[panel, const SizedBox(height: 18)],
          table,
        ],
      ],
    );
  }

  Widget _buildTable(List<ProductModel> items, List<ProductModel> pageItems, int page, int pages) {
    return AdminPanel(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  height: 42,
                  child: AdminSearchField(
                    hint: 'Search products or SKU',
                    onChanged: (v) => setState(() {
                      _query = v;
                      _page = 0;
                    }),
                  ),
                ),
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _categoryFilter,
                      borderRadius: BorderRadius.circular(12),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All Categories')),
                        ..._categories.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (v) => setState(() {
                        _categoryFilter = v;
                        _page = 0;
                      }),
                    ),
                  ),
                ),
                AdminSegmented<String>(
                  filled: false,
                  options: const [('all', 'All'), ('active', 'Active'), ('hidden', 'Hidden')],
                  value: _tab,
                  onChanged: (v) => setState(() {
                    _tab = v;
                    _page = 0;
                  }),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          AdminTable(
            columns: const ['Product', 'Category', 'Variants', 'Price', 'Stock', 'In store', ''],
            flex: const [2.6, 1.6, 0.7, 1.0, 1.1, 0.8, 0.5],
            minWidth: 860,
            empty: const Padding(
              padding: EdgeInsets.all(28),
              child: Text('No products match these filters', style: TextStyle(color: AppColors.textSecondary)),
            ),
            rows: pageItems.map((p) {
              final v = p.defaultVariant;
              final stock = p.variants.fold<int>(0, (s, x) => s + x.stockQuantity);
              final visible = SupabaseService().isProductVisible(p.id);
              final stockStyle = stock == 0
                  ? ('Out of stock', AppColors.errorLight, AppColors.error)
                  : stock < 15
                      ? ('$stock · Low', AppColors.accentLight, AppColors.accentInk)
                      : ('$stock units', AppColors.primaryLight, AppColors.primaryDeep);
              return <Widget>[
                Row(
                  children: [
                    SizedBox(width: 40, height: 40, child: QbProductImage(product: p, radius: 10, iconSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                          Text('${p.brand}${v.sku != null ? ' · ${v.sku}' : ''}',
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(_categoryName(p.categoryId), maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
                Text('${p.variants.length}', style: const TextStyle(fontSize: 13)),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '₹${v.sellingPrice.toStringAsFixed(0)} ', style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (v.mrp > v.sellingPrice)
                      TextSpan(
                        text: '₹${v.mrp.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted, decoration: TextDecoration.lineThrough),
                      ),
                  ]),
                  style: const TextStyle(fontSize: 13),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: QbPill(label: stockStyle.$1, background: stockStyle.$2, foreground: stockStyle.$3, fontSize: 12),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AdminSwitch(
                    value: visible,
                    semanticLabel: 'Active in customer store',
                    onChanged: (on) {
                      SupabaseService().setProductVisibility(p.id, on);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${p.name} is now ${on ? 'visible in' : 'hidden from'} the store')),
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton.outlined(
                    tooltip: 'Edit product',
                    onPressed: () => _startEdit(p),
                    style: IconButton.styleFrom(side: const BorderSide(color: AppColors.border), minimumSize: const Size(34, 34)),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                  ),
                ),
              ];
            }).toList(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    items.isEmpty
                        ? 'No products'
                        : 'Showing ${page * _pageSize + 1}–${page * _pageSize + pageItems.length} of ${items.length} products',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                OutlinedButton(
                  onPressed: page > 0 ? () => setState(() => _page = page - 1) : null,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), side: const BorderSide(color: AppColors.border)),
                  child: const Text('Previous'),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: page < pages - 1 ? () => setState(() => _page = page + 1) : null,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), side: const BorderSide(color: AppColors.border)),
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {String? hint, bool number = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textBody)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          inputFormatters: number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textBody)),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: value,
          key: ValueKey('$label-$value-${items.length}'),
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          borderRadius: BorderRadius.circular(12),
        ),
      ],
    );
  }

  Widget _buildPanel() {
    final isEdit = _editing != null;
    Widget pair(Widget a, Widget b) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)],
        );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: qbCard(shadow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(isEdit ? 'Edit Product' : 'Add Product to Store',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              IconButton.outlined(
                tooltip: 'Close',
                onPressed: () {
                  setState(() => _panelOpen = false);
                  _resetForm();
                },
                style: IconButton.styleFrom(side: const BorderSide(color: AppColors.border)),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFB9CDBF), width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: _imageCtrl.text.trim().startsWith('http')
                ? Image.network(_imageCtrl.text.trim(), fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Center(child: Text('Image could not be loaded')))
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_outlined, color: AppColors.primary, size: 28),
                      SizedBox(height: 6),
                      Text('Paste an image URL below to preview', style: TextStyle(fontSize: 13, color: AppColors.textBody)),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _imageCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Image URL (optional)', prefixIcon: Icon(Icons.link_rounded, size: 18)),
          ),
          const SizedBox(height: 12),
          _field('Product Name', _nameCtrl, hint: 'e.g. Fresh Red Onions'),
          const SizedBox(height: 12),
          pair(_field('Brand', _brandCtrl), _field('Unit / Pack', _unitCtrl, hint: '1 kg / 500 ml')),
          const SizedBox(height: 12),
          pair(
            _dropdownField<String>(
              label: 'Category',
              value: _formCategory,
              items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) {
                if (v != null) _selectFormCategory(v);
              },
            ),
            _dropdownField<String?>(
              label: 'Subcategory',
              value: _formSubcategory,
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('None')),
                ..._subcategories.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() => _formSubcategory = v),
            ),
          ),
          const SizedBox(height: 12),
          pair(_field('MRP (₹)', _mrpCtrl, number: true), _field('Selling Price (₹)', _priceCtrl, number: true)),
          const SizedBox(height: 12),
          pair(_field(isEdit ? 'Stock' : 'Initial Stock', _stockCtrl, number: true), _field('SKU', _skuCtrl, hint: 'Optional')),
          const SizedBox(height: 12),
          _field('Description', _descCtrl, hint: 'Short product description'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Active in Customer Store', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      Text('Visible to shoppers right away', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Switch(value: _formActive, onChanged: (v) => setState(() => _formActive = v)),
              ],
            ),
          ),
          if (_formError != null) ...[
            const SizedBox(height: 12),
            Text(_formError!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _resetForm,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  child: Text(isEdit ? 'Cancel edit' : 'Clear'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Save changes' : 'Add product'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
