import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/product_model.dart';
import '../../../services/mock_data_service.dart';
import '../../../services/supabase_service.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../widgets/admin_ui.dart';

/// Store Inventory & Product Management (PRD Section 6)
///
/// Stock per variant with low/out-of-stock filters, quick stock adjustment,
/// CSV stock import and purchase-order generation.
class AdminInventoryScreen extends StatefulWidget {
  const AdminInventoryScreen({super.key});

  @override
  State<AdminInventoryScreen> createState() => _AdminInventoryScreenState();
}

class _AdminInventoryScreenState extends State<AdminInventoryScreen> {
  static const int reorderLevel = 15;

  String _searchQuery = '';
  String? _selectedCategory;
  String _tab = 'all';
  List<ProductModel> _products = [];

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

  Future<void> _adjustStock(ProductModel product, ProductVariant variant, int delta) async {
    final newStock = (variant.stockQuantity + delta).clamp(0, 9999);
    await SupabaseService().updateProductStock(product.id, variant.id, newStock);
    _loadProducts();
  }

  List<(ProductModel, ProductVariant)> get _rows {
    final rows = <(ProductModel, ProductVariant)>[];
    for (final p in _products) {
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.brand.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.variants.any((v) => (v.sku ?? '').toLowerCase().contains(_searchQuery.toLowerCase()));
      final matchesCategory = _selectedCategory == null || p.categoryId == _selectedCategory;
      if (!matchesSearch || !matchesCategory) continue;
      for (final v in p.variants) {
        final out = v.stockQuantity == 0;
        final low = !out && v.stockQuantity < reorderLevel;
        if (_tab == 'low' && !low) continue;
        if (_tab == 'out' && !out) continue;
        rows.add((p, v));
      }
    }
    rows.sort((a, b) => a.$2.stockQuantity.compareTo(b.$2.stockQuantity));
    return rows;
  }

  Iterable<ProductVariant> get _allVariants => _products.expand((p) => p.variants);

  String _skuOf(ProductModel p, ProductVariant v) => v.sku ?? v.id.toUpperCase();

  // -------------------------------------------------------------- Import CSV

  void _showImportDialog() {
    final ctrl = TextEditingController();
    String? result;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Import stock from CSV', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Paste rows as  sku_or_variant_id,stock  (one per line). Matching variants are set to the new stock level.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  maxLines: 8,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(hintText: '${_allVariants.isNotEmpty ? _allVariants.first.id : 'var-1'},40'),
                ),
                if (result != null) ...[
                  const SizedBox(height: 10),
                  Text(result!, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDeep)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ElevatedButton(
              onPressed: () async {
                var updated = 0;
                var skipped = 0;
                for (final line in ctrl.text.split('\n')) {
                  final parts = line.split(',').map((s) => s.trim()).toList();
                  if (parts.length < 2) continue;
                  final qty = int.tryParse(parts[1]);
                  if (qty == null || qty < 0) {
                    skipped++;
                    continue;
                  }
                  var matched = false;
                  for (final p in MockDataService.products) {
                    for (final v in p.variants) {
                      if (v.id.toLowerCase() == parts[0].toLowerCase() || (v.sku ?? '').toLowerCase() == parts[0].toLowerCase()) {
                        await SupabaseService().updateProductStock(p.id, v.id, qty);
                        matched = true;
                      }
                    }
                  }
                  matched ? updated++ : skipped++;
                }
                _loadProducts();
                setD(() => result = 'Updated $updated rows${skipped > 0 ? ' · skipped $skipped' : ''}');
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------- Purchase order

  void _showPurchaseOrder() {
    final items = <(ProductModel, ProductVariant, int)>[];
    for (final p in _products) {
      for (final v in p.variants) {
        if (v.stockQuantity < reorderLevel) items.add((p, v, reorderLevel * 3 - v.stockQuantity));
      }
    }
    items.sort((a, b) => a.$2.stockQuantity.compareTo(b.$2.stockQuantity));
    final csv = StringBuffer('sku,product,unit,current_stock,order_qty\n');
    for (final i in items) {
      csv.writeln([_skuOf(i.$1, i.$2), i.$1.name, i.$2.unit, i.$2.stockQuantity, i.$3].map(csvCell).join(','));
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Purchase order', style: TextStyle(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 560,
          child: items.isEmpty
              ? const Text('Everything is above the reorder level — nothing to order.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('${items.length} items below the reorder level of $reorderLevel',
                        style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView(
                        shrinkWrap: true,
                        children: items
                            .map((i) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: SizedBox(width: 36, height: 36, child: QbProductImage(product: i.$1, radius: 8, iconSize: 18)),
                                  title: Text('${i.$1.name} · ${i.$2.unit}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text('In stock: ${i.$2.stockQuantity}'),
                                  trailing: Text('Order ${i.$3}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          if (items.isNotEmpty) ...[
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                showCsvExportDialog(context, title: 'Purchase order CSV', csv: csv.toString().trimRight());
              },
              child: const Text('Export CSV'),
            ),
            ElevatedButton(
              onPressed: () async {
                for (final i in items) {
                  await SupabaseService().updateProductStock(i.$1.id, i.$2.id, i.$2.stockQuantity + i.$3);
                }
                _loadProducts();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Purchase order received — ${items.length} items restocked')),
                  );
                }
              },
              child: const Text('Mark as received'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final variants = _allVariants.toList();
    final out = variants.where((v) => v.stockQuantity == 0).length;
    final low = variants.where((v) => v.stockQuantity > 0 && v.stockQuantity < reorderLevel).length;
    final value = _products.fold<double>(
      0,
      (s, p) => s + p.variants.fold<double>(0, (t, v) => t + v.stockQuantity * v.sellingPrice),
    );
    final rows = _rows;

    final tiles = [
      ('Total SKUs', '${variants.length}', AppColors.primaryLight, AppColors.primaryDeep, Icons.inventory_2_outlined),
      ('Low stock', '$low', AppColors.accentLight, AppColors.accentInk, Icons.warning_amber_rounded),
      ('Out of stock', '$out', AppColors.errorLight, AppColors.error, Icons.block_rounded),
      ('Stock value', qbRupees(value), AppColors.infoLight, const Color(0xFF34479A), Icons.trending_up_rounded),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(mobile ? 16 : 32, 24, mobile ? 16 : 32, 40),
      children: [
        AdminPageHeader(
          title: 'Store Inventory',
          subtitle: 'Koramangala Dark Store · stock per variant',
          actions: [
            OutlinedButton.icon(
              onPressed: _showImportDialog,
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: const Text('Import CSV'),
              style: OutlinedButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: AppColors.border)),
            ),
            ElevatedButton(onPressed: _showPurchaseOrder, child: const Text('Create purchase order')),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 460 ? 2 : 1);
            final w = (c.maxWidth - (cols - 1) * 14) / cols;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: tiles
                  .map((t) => SizedBox(
                        width: w,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: qbCard(radius: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(color: t.$3, borderRadius: BorderRadius.circular(12)),
                                child: Icon(t.$5, color: t.$4),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.$1,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(t.$2, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 18),
        AdminPanel(
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
                    AdminSegmented<String>(
                      filled: false,
                      options: [('all', 'All items'), ('low', 'Low stock ($low)'), ('out', 'Out of stock ($out)')],
                      value: _tab,
                      onChanged: (v) => setState(() => _tab = v),
                    ),
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedCategory,
                          borderRadius: BorderRadius.circular(12),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('All Categories')),
                            ...MockDataService.categories.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name))),
                          ],
                          onChanged: (v) => setState(() => _selectedCategory = v),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      height: 42,
                      child: AdminSearchField(hint: 'Search SKU or product', onChanged: (v) => setState(() => _searchQuery = v)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              AdminTable(
                columns: const ['Product · Variant', 'SKU', 'Stock level', 'Reorder at', 'Status', 'Adjust stock'],
                flex: const [2.4, 1.3, 1.6, 0.8, 1.1, 1.2],
                minWidth: 900,
                empty: const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text('No items match these filters', style: TextStyle(color: AppColors.textSecondary)),
                ),
                rows: rows.map((r) {
                  final p = r.$1;
                  final v = r.$2;
                  final isOut = v.stockQuantity == 0;
                  final isLow = !isOut && v.stockQuantity < reorderLevel;
                  final st = isOut
                      ? ('Out of stock', AppColors.errorLight, AppColors.error, Icons.close_rounded, AppColors.error)
                      : isLow
                          ? ('Low stock', AppColors.accentLight, AppColors.accentInk, Icons.priority_high_rounded, const Color(0xFFE0A100))
                          : ('In stock', AppColors.primaryLight, AppColors.primaryDeep, Icons.check_rounded, AppColors.primary);
                  return <Widget>[
                    Row(
                      children: [
                        SizedBox(width: 36, height: 36, child: QbProductImage(product: p, radius: 9, iconSize: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                              Text(v.unit, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(_skuOf(p, v), maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textBody)),
                    Row(
                      children: [
                        Expanded(child: AdminMeter(fraction: v.stockQuantity / 150, color: st.$5)),
                        const SizedBox(width: 10),
                        Text('${v.stockQuantity}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const Text('$reorderLevel', style: TextStyle(fontSize: 13, color: AppColors.textBody)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: QbPill(label: st.$1, icon: st.$4, background: st.$2, foreground: st.$3, fontSize: 12),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderStrong),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Decrease stock',
                              visualDensity: VisualDensity.compact,
                              onPressed: v.stockQuantity == 0 ? null : () => _adjustStock(p, v, -1),
                              icon: const Icon(Icons.remove_rounded, size: 18),
                            ),
                            SizedBox(
                              width: 40,
                              child: Text('${v.stockQuantity}',
                                  textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            IconButton(
                              tooltip: 'Increase stock',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _adjustStock(p, v, 1),
                              icon: const Icon(Icons.add_rounded, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ];
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
