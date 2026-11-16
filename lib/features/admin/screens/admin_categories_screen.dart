import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/image_upload_helper.dart';
import '../../../models/category_model.dart';
import '../../../models/subcategory_model.dart';
import '../../../services/supabase_service.dart';
import '../../../services/mock_data_service.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../widgets/admin_ui.dart';

/// Dark Store Category & Subcategory Management Screen (PRD Sections 4.4, 5.4, 6)
class AdminCategoriesScreen extends StatefulWidget {
  /// When true the screen renders as a page inside the admin shell
  /// (no Scaffold / app bar of its own).
  final bool embedded;

  const AdminCategoriesScreen({super.key, this.embedded = false});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CategoryModel> _categories = [];
  List<SubcategoryModel> _subcategories = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedCategoryFilter;

  // Preset image collections for quick 1-click selection
  final List<Map<String, String>> _categoryPresets = [
    {'name': 'Fruits & Vegetables', 'url': 'https://images.unsplash.com/photo-1610832958506-aa56368176cf', 'color': '#E8F5E9', 'icon': 'eco'},
    {'name': 'Dairy, Bread & Eggs', 'url': 'https://images.unsplash.com/photo-1550583724-b2692b85b150', 'color': '#FFF8E1', 'icon': 'egg'},
    {'name': 'Atta, Rice & Pulses', 'url': 'https://images.unsplash.com/photo-1586201375761-83865001e31c', 'color': '#FFF3E0', 'icon': 'grain'},
    {'name': 'Snacks & Munchies', 'url': 'https://images.unsplash.com/photo-1566478989037-eec170784d0b', 'color': '#FBE9E7', 'icon': 'fastfood'},
    {'name': 'Cold Drinks & Juices', 'url': 'https://images.unsplash.com/photo-1527661591475-527312dd65f5', 'color': '#E1F5FE', 'icon': 'local_drink'},
    {'name': 'Bakery & Biscuits', 'url': 'https://images.unsplash.com/photo-1509440159596-0249088772ff', 'color': '#EDE7F6', 'icon': 'bakery_dining'},
    {'name': 'Personal Care', 'url': 'https://images.unsplash.com/photo-1556228720-195a672e8a03', 'color': '#E0F7FA', 'icon': 'spa'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    SupabaseService().categoriesNotifier.addListener(_onCategoriesNotifierChanged);
  }

  @override
  void dispose() {
    SupabaseService().categoriesNotifier.removeListener(_onCategoriesNotifierChanged);
    _tabController.dispose();
    _editName.dispose();
    _editSlug.dispose();
    _editOrder.dispose();
    super.dispose();
  }

  void _onCategoriesNotifierChanged() {
    if (mounted) {
      _loadData(silent: true);
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final cats = await SupabaseService().getAllCategories();
      final subs = await SupabaseService().getSubcategories(includeInactive: true);
      if (mounted) {
        setState(() {
          _categories = cats;
          _subcategories = subs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<CategoryModel> get _filteredCategories {
    if (_searchQuery.trim().isEmpty) return _categories;
    final q = _searchQuery.trim().toLowerCase();
    return _categories.where((c) => c.name.toLowerCase().contains(q) || c.slug.toLowerCase().contains(q)).toList();
  }

  // ==========================================
  // CATEGORY ACTIONS
  // ==========================================

  Future<void> _toggleCategoryActive(CategoryModel category, bool isActive) async {
    await SupabaseService().toggleCategoryStatus(category.id, isActive);
    _loadData(silent: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${category.name} is now ${isActive ? "Active (visible to customers)" : "Deactivated (hidden from store)"}'),
          backgroundColor: isActive ? const Color(0xFF0C8340) : AppColors.textSecondary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showCategoryDialog({CategoryModel? category}) {
    final isEditing = category != null;
    final nameCtrl = TextEditingController(text: category?.name ?? '');
    final slugCtrl = TextEditingController(text: category?.slug ?? '');
    final imgCtrl = TextEditingController(text: category?.imageUrl ?? '');
    final orderCtrl = TextEditingController(text: (category?.displayOrder ?? _categories.length + 1).toString());
    String colorHex = category?.colorHex ?? '#E8F5E9';
    String iconName = category?.iconName ?? 'category';
    bool isActive = category?.isActive ?? true;
    bool isSaving = false;
    bool isUploadingImage = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded, color: const Color(0xFF064E26)),
              const SizedBox(width: 8),
              Text(isEditing ? 'Edit Category' : 'Add New Category', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Name
                  const Text('Category Name *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    onChanged: (val) {
                      if (!isEditing && val.isNotEmpty) {
                        slugCtrl.text = val.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'e.g. Organic & Gourmet',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Slug
                  const Text('Slug (URL friendly key)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: slugCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. organic-gourmet',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Display Order
                  const Text('Display Order', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: orderCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '1',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Category Image Section
                  const Text('Category Image', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: imgCtrl,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Image URL or upload below',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Upload from Device Button
                      ElevatedButton.icon(
                        onPressed: isUploadingImage
                            ? null
                            : () async {
                                setDialogState(() => isUploadingImage = true);
                                try {
                                  final fileResult = await ImageUploadHelper.pickImage();
                                  if (fileResult != null) {
                                    final uploadedUrl = await SupabaseService().uploadCategoryImage(
                                      bytes: fileResult.bytes,
                                      fileName: fileResult.fileName,
                                    );
                                    if (uploadedUrl != null) {
                                      setDialogState(() {
                                        imgCtrl.text = uploadedUrl;
                                        isUploadingImage = false;
                                      });
                                    }
                                  } else {
                                    setDialogState(() => isUploadingImage = false);
                                  }
                                } catch (_) {
                                  setDialogState(() => isUploadingImage = false);
                                }
                              },
                        icon: isUploadingImage
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.upload_file_rounded, size: 18),
                        label: const Text('Upload'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF064E26),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Image Preview
                  if (imgCtrl.text.trim().isNotEmpty) ...[
                    Container(
                      height: 80,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.network(
                          imgCtrl.text.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_rounded, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Quick Image Presets
                  const Text('Or Select Preset Theme:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _categoryPresets.map((p) {
                      return ActionChip(
                        label: Text(p['name']!, style: const TextStyle(fontSize: 11)),
                        backgroundColor: const Color(0xFFF3F4F6),
                        onPressed: () {
                          setDialogState(() {
                            nameCtrl.text = isEditing ? nameCtrl.text : p['name']!;
                            if (!isEditing) slugCtrl.text = p['name']!.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
                            imgCtrl.text = p['url']!;
                            colorHex = p['color']!;
                            iconName = p['icon']!;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Active Switch
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active in Customer Store', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text(
                      isActive ? 'Customers can browse and buy items from this category' : 'Hidden from storefront',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    value: isActive,
                    activeColor: const Color(0xFF0C8340),
                    onChanged: (val) => setDialogState(() => isActive = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      var slug = slugCtrl.text.trim();
                      final order = int.tryParse(orderCtrl.text.trim()) ?? 0;
                      final img = imgCtrl.text.trim().isNotEmpty ? imgCtrl.text.trim() : null;

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter category name'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      if (slug.isEmpty) {
                        slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
                      }

                      setDialogState(() => isSaving = true);

                      if (isEditing) {
                        final updated = category.copyWith(
                          name: name,
                          slug: slug,
                          imageUrl: img,
                          colorHex: colorHex,
                          iconName: iconName,
                          displayOrder: order,
                          isActive: isActive,
                        );
                        await SupabaseService().updateCategory(updated);
                      } else {
                        await SupabaseService().createCategory(
                          name: name,
                          slug: slug,
                          imageUrl: img,
                          colorHex: colorHex,
                          iconName: iconName,
                          displayOrder: order,
                          isActive: isActive,
                        );
                      }

                      if (mounted) {
                        Navigator.pop(ctx);
                        _loadData(silent: true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isEditing ? 'Category updated successfully!' : 'Category created successfully!'),
                            backgroundColor: const Color(0xFF0C8340),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C8340),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(isEditing ? 'Save Changes' : 'Create Category', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCategory(CategoryModel category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text('Delete "${category.name}"?', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
          ],
        ),
        content: const Text(
          'This will remove the category and all its assigned subcategories from the customer app. Are you sure?',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SupabaseService().deleteCategory(category.id);
              _loadData(silent: true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Category "${category.name}" deleted'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete Category', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SUBCATEGORY ACTIONS
  // ==========================================

  Future<void> _toggleSubcategoryActive(SubcategoryModel sub, bool isActive) async {
    await SupabaseService().toggleSubcategoryStatus(sub.id, isActive);
    _loadData(silent: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${sub.name} is now ${isActive ? "Active" : "Deactivated"}'),
          backgroundColor: isActive ? const Color(0xFF0C8340) : AppColors.textSecondary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showSubcategoryDialog({SubcategoryModel? subcategory}) {
    final isEditing = subcategory != null;
    String parentCatId = subcategory?.categoryId ??
        (_selectedCategoryFilter != null && _selectedCategoryFilter!.isNotEmpty
            ? _selectedCategoryFilter!
            : (_categories.isNotEmpty ? _categories.first.id : ''));
    final nameCtrl = TextEditingController(text: subcategory?.name ?? '');
    final slugCtrl = TextEditingController(text: subcategory?.slug ?? '');
    final imgCtrl = TextEditingController(text: subcategory?.imageUrl ?? '');
    final orderCtrl = TextEditingController(text: (subcategory?.displayOrder ?? _subcategories.length + 1).toString());
    bool isActive = subcategory?.isActive ?? true;
    bool isSaving = false;
    bool isUploadingImage = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded, color: const Color(0xFF064E26)),
              const SizedBox(width: 8),
              Text(isEditing ? 'Edit Subcategory' : 'Add New Subcategory', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Parent Category Selector
                  const Text('Assign to Parent Category *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _categories.any((c) => c.id == parentCatId) ? parentCatId : (_categories.isNotEmpty ? _categories.first.id : null),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: _categories.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => parentCatId = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Subcategory Name
                  const Text('Subcategory Name *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    onChanged: (val) {
                      if (!isEditing && val.isNotEmpty) {
                        slugCtrl.text = val.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'e.g. Milk & Cream',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Slug
                  const Text('Slug', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: slugCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. milk-cream',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Display Order
                  const Text('Display Order', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: orderCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '1',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Image / Upload
                  const Text('Subcategory Image', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: imgCtrl,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Image URL or upload',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: isUploadingImage
                            ? null
                            : () async {
                                setDialogState(() => isUploadingImage = true);
                                try {
                                  final fileResult = await ImageUploadHelper.pickImage();
                                  if (fileResult != null) {
                                    final uploadedUrl = await SupabaseService().uploadCategoryImage(
                                      bytes: fileResult.bytes,
                                      fileName: fileResult.fileName,
                                    );
                                    if (uploadedUrl != null) {
                                      setDialogState(() {
                                        imgCtrl.text = uploadedUrl;
                                        isUploadingImage = false;
                                      });
                                    }
                                  } else {
                                    setDialogState(() => isUploadingImage = false);
                                  }
                                } catch (_) {
                                  setDialogState(() => isUploadingImage = false);
                                }
                              },
                        icon: isUploadingImage
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.upload_file_rounded, size: 18),
                        label: const Text('Upload'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF064E26),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (imgCtrl.text.trim().isNotEmpty) ...[
                    Container(
                      height: 70,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.network(
                          imgCtrl.text.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_rounded, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Active Switch
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active Subcategory', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text(
                      isActive ? 'Visible as a filter chip on customer screen' : 'Hidden from customer store',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    value: isActive,
                    activeColor: const Color(0xFF0C8340),
                    onChanged: (val) => setDialogState(() => isActive = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      var slug = slugCtrl.text.trim();
                      final order = int.tryParse(orderCtrl.text.trim()) ?? 0;
                      final img = imgCtrl.text.trim().isNotEmpty ? imgCtrl.text.trim() : null;

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter subcategory name'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      if (slug.isEmpty) {
                        slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
                      }

                      setDialogState(() => isSaving = true);

                      if (isEditing) {
                        final updated = subcategory.copyWith(
                          categoryId: parentCatId,
                          name: name,
                          slug: slug,
                          imageUrl: img,
                          displayOrder: order,
                          isActive: isActive,
                        );
                        await SupabaseService().updateSubcategory(updated);
                      } else {
                        await SupabaseService().createSubcategory(
                          categoryId: parentCatId,
                          name: name,
                          slug: slug,
                          imageUrl: img,
                          displayOrder: order,
                          isActive: isActive,
                        );
                      }

                      if (mounted) {
                        Navigator.pop(ctx);
                        _loadData(silent: true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isEditing ? 'Subcategory updated!' : 'Subcategory created!'),
                            backgroundColor: const Color(0xFF0C8340),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C8340),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(isEditing ? 'Save Changes' : 'Create Subcategory', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSubcategory(SubcategoryModel subcategory) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text('Delete "${subcategory.name}"?', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this subcategory?',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SupabaseService().deleteSubcategory(subcategory.id);
              _loadData(silent: true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Subcategory "${subcategory.name}" deleted'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete Subcategory', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MASTER-DETAIL LAYOUT
  // ==========================================

  final TextEditingController _editName = TextEditingController();
  final TextEditingController _editSlug = TextEditingController();
  final TextEditingController _editOrder = TextEditingController();
  String? _editColor;
  String? _editLoadedFor;
  bool _savingInline = false;

  static const List<String> _presetSwatches = [
    '#E8F5E9', '#FFF8E1', '#FFF3E0', '#FBE9E7', '#E1F5FE', '#F3E5F5', '#EDE7F6', '#E0F2F1',
  ];

  CategoryModel? get _selectedCategory {
    if (_categories.isEmpty) return null;
    return _categories.where((c) => c.id == _selectedCategoryFilter).firstOrNull ?? _categories.first;
  }

  String _formKey(CategoryModel cat) => '${cat.id}|${cat.name}|${cat.slug}|${cat.displayOrder}|${cat.colorHex}';

  void _syncInlineForm(CategoryModel cat) {
    if (_editLoadedFor == _formKey(cat)) return;
    _editLoadedFor = _formKey(cat);
    _editName.text = cat.name;
    _editSlug.text = cat.slug;
    _editOrder.text = '${cat.displayOrder}';
    _editColor = cat.colorHex ?? '#E8F5E9';
  }

  Future<void> _saveInline(CategoryModel cat) async {
    final name = _editName.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter category name')));
      return;
    }
    setState(() => _savingInline = true);
    final slug = _editSlug.text.trim().isEmpty
        ? name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '')
        : _editSlug.text.trim();
    await SupabaseService().updateCategory(cat.copyWith(
      name: name,
      slug: slug,
      displayOrder: int.tryParse(_editOrder.text.trim()) ?? cat.displayOrder,
      colorHex: _editColor,
    ));
    await _loadData(silent: true);
    if (!mounted) return;
    setState(() => _savingInline = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name saved')));
  }

  int _productCountForSub(SubcategoryModel s) =>
      MockDataService.products.where((p) => p.subcategoryId == s.id).length;

  @override
  Widget build(BuildContext context) {
    final page = _buildPage();
    if (widget.embedded) return page;
    return Scaffold(
      backgroundColor: AppColors.adminBackground,
      appBar: AppBar(title: const Text('Categories & Subcategories')),
      body: page,
    );
  }

  Widget _buildPage() {
    final mobile = Responsive.isMobile(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final selected = _selectedCategory;
    if (selected != null) _syncInlineForm(selected);

    final master = _buildMasterList(_filteredCategories, selected);
    final detail = selected == null
        ? AdminPanel(
            child: Column(
              children: [
                const Text('No categories yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ElevatedButton(onPressed: () => _showCategoryDialog(), child: const Text('Create First Category')),
              ],
            ),
          )
        : _buildDetail(selected);

    return ListView(
      padding: EdgeInsets.fromLTRB(mobile ? 16 : 32, 24, mobile ? 16 : 32, 40),
      children: [
        AdminPageHeader(
          title: 'Categories & Subcategories',
          subtitle: 'Changes appear in the customer app instantly',
          actions: [
            OutlinedButton.icon(
              onPressed: () => _loadData(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: AppColors.border)),
            ),
            ElevatedButton.icon(
              onPressed: () => _showCategoryDialog(),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add Category'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 900) return Column(children: [master, const SizedBox(height: 18), detail]);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [SizedBox(width: 360, child: master), const SizedBox(width: 18), Expanded(child: detail)],
            );
          },
        ),
      ],
    );
  }

  Widget _categoryTile(String? imageUrl, String? colorHex, String? iconName, double size, double radius) {
    final visual = CategoryVisual.of(CategoryModel(id: '', name: '', slug: '', iconName: iconName, colorHex: colorHex));
    final tint = CategoryVisual.parseHex(colorHex, fallback: visual.tint);
    final url = imageUrl ?? '';
    final hasImage = url.startsWith('http') || url.startsWith('data:');
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(visual.icon, color: visual.ink, size: size * 0.5))
          : Icon(visual.icon, color: visual.ink, size: size * 0.5),
    );
  }

  Widget _buildMasterList(List<CategoryModel> categories, CategoryModel? selected) {
    final active = _categories.where((c) => c.isActive).length;
    return AdminPanel(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text('Main Categories (${_categories.length})',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
                Text('$active active', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: SizedBox(
              height: 42,
              child: AdminSearchField(hint: 'Search categories', onChanged: (v) => setState(() => _searchQuery = v)),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 760),
            child: categories.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No categories found', style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    itemCount: categories.length,
                    itemBuilder: (context, i) {
                      final c = categories[i];
                      final on = c.id == selected?.id;
                      final subs = _subcategories.where((s) => s.categoryId == c.id).length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: on ? AppColors.primaryTint : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: on ? AppColors.primary : Colors.transparent, width: 1.5),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => _selectedCategoryFilter = c.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  _categoryTile(c.imageUrl, c.colorHex, c.iconName, 38, 10),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                        Text('$subs subcategories · #${c.displayOrder}',
                                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  QbPill(
                                    label: c.isActive ? 'Active' : 'Hidden',
                                    background: c.isActive ? AppColors.primaryLight : AppColors.surfaceMuted,
                                    foreground: c.isActive ? AppColors.primaryDeep : AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _labeled(String label, Widget field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textBody)),
          const SizedBox(height: 6),
          field,
        ],
      );

  Widget _buildDetail(CategoryModel cat) {
    final subs = _subcategories.where((s) => s.categoryId == cat.id).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final dirty = _editName.text.trim() != cat.name ||
        _editSlug.text.trim() != cat.slug ||
        _editOrder.text.trim() != '${cat.displayOrder}' ||
        _editColor != (cat.colorHex ?? '#E8F5E9');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _categoryTile(cat.imageUrl, _editColor, cat.iconName, 64, 18),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      Text('/${cat.slug} · display order ${cat.displayOrder}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cat.isActive ? 'Active in store' : 'Hidden from store',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      AdminSwitch(
                        value: cat.isActive,
                        semanticLabel: 'Active in customer store',
                        onChanged: (v) => _toggleCategoryActive(cat, v),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _confirmDeleteCategory(cat),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete Category'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.errorBorder),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth >= 640 ? 3 : 1;
                final w = (c.maxWidth - (cols - 1) * 14) / cols;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    SizedBox(
                      width: w,
                      child: _labeled('Category Name *', TextField(controller: _editName, onChanged: (_) => setState(() {}))),
                    ),
                    SizedBox(
                      width: w,
                      child: _labeled('Slug (URL friendly key)', TextField(controller: _editSlug, onChanged: (_) => setState(() {}))),
                    ),
                    SizedBox(
                      width: w,
                      child: _labeled(
                        'Display Order',
                        TextField(controller: _editOrder, keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  _labeled(
                    'Preset theme',
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presetSwatches.map((hex) {
                        final on = hex.toLowerCase() == (_editColor ?? '').toLowerCase();
                        return Tooltip(
                          message: 'Theme $hex',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _editColor = hex),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: CategoryVisual.parseHex(hex),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: on ? AppColors.primary : AppColors.border, width: on ? 2 : 1),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  _labeled(
                    'Category Image',
                    OutlinedButton.icon(
                      onPressed: () => _showCategoryDialog(category: cat),
                      icon: const Icon(Icons.upload_rounded, size: 18),
                      label: const Text('Upload'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        backgroundColor: const Color(0xFFF8FAF8),
                        side: const BorderSide(color: Color(0xFFB9CDBF), width: 1.5),
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 0,
                    runSpacing: 10,
                    children: [
                      OutlinedButton(
                        onPressed: dirty
                            ? () => setState(() {
                                  _editLoadedFor = null;
                                  _syncInlineForm(cat);
                                })
                            : null,
                        child: const Text('Discard'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: dirty && !_savingInline ? () => _saveInline(cat) : null,
                        child: _savingInline
                            ? const SizedBox(
                                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save Changes'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AdminPanel(
          padding: EdgeInsets.zero,
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Subcategories (${subs.length})',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        _selectedCategoryFilter = cat.id;
                        _showSubcategoryDialog();
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Subcategory'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.primaryTint,
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.all(16),
                child: subs.isEmpty
                    ? const Text('No subcategories found — add one to organise this category.',
                        style: TextStyle(color: AppColors.textSecondary))
                    : LayoutBuilder(builder: (context, c) {
                        final cols = (c.maxWidth / 300).floor().clamp(1, 3);
                        final w = (c.maxWidth - (cols - 1) * 12) / cols;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: subs.map((s) => SizedBox(width: w, child: _subcategoryCard(s, cat))).toList(),
                        );
                      }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _subcategoryCard(SubcategoryModel s, CategoryModel cat) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: s.isActive ? Colors.white : const Color(0xFFFAFBFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: s.isActive ? 1 : 0.45,
            child: _categoryTile(s.imageUrl, cat.colorHex, cat.iconName, 44, 12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text('${_productCountForSub(s)} products · ${s.isActive ? 'Active' : 'Deactivated'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          AdminSwitch(
            value: s.isActive,
            semanticLabel: 'Active Subcategory',
            onChanged: (v) => _toggleSubcategoryActive(s, v),
          ),
          PopupMenuButton<String>(
            tooltip: 'More actions',
            icon: const Icon(Icons.more_vert_rounded, size: 18),
            onSelected: (v) {
              if (v == 'edit') _showSubcategoryDialog(subcategory: s);
              if (v == 'delete') _confirmDeleteSubcategory(s);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit subcategory')),
              PopupMenuItem(value: 'delete', child: Text('Delete subcategory')),
            ],
          ),
        ],
      ),
    );
  }
}
