import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/image_upload_helper.dart';
import '../../../models/category_model.dart';
import '../../../models/subcategory_model.dart';
import '../../../services/supabase_service.dart';
import '../../../shared_widgets/responsive_wrapper.dart';

/// Dark Store Category & Subcategory Management Screen (PRD Sections 4.4, 5.4, 6)
class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

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

  List<SubcategoryModel> get _filteredSubcategories {
    var list = _subcategories;
    if (_selectedCategoryFilter != null && _selectedCategoryFilter!.isNotEmpty) {
      list = list.where((s) => s.categoryId == _selectedCategoryFilter).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((s) => s.name.toLowerCase().contains(q) || s.slug.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  String _getParentCategoryName(String categoryId) {
    final cat = _categories.where((c) => c.id == categoryId).firstOrNull;
    return cat?.name ?? 'Unknown Category';
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

  @override
  Widget build(BuildContext context) {
    final filteredCats = _filteredCategories;
    final filteredSubs = _filteredSubcategories;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF064E26),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category & Subcategory Management',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.2),
            ),
            Text(
              'Manage dynamic categories, subcategory hierarchy & active storefront status',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Categories',
            onPressed: () => _loadData(),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFD700),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.grid_view_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Main Categories (${_categories.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_tree_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Subcategories (${_subcategories.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: ResponsiveWrapper(
        maxWidth: 1100,
        child: Column(
          children: [
            // Top Action & Search Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Search Field
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search categories or subcategories...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Add Button
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_tabController.index == 0) {
                        _showCategoryDialog();
                      } else {
                        _showSubcategoryDialog();
                      }
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      _tabController.index == 0 ? 'Add Category' : 'Add Subcategory',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0C8340),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF064E26)))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // 1. Main Categories Tab
                        _buildCategoriesList(filteredCats),

                        // 2. Subcategories Tab
                        _buildSubcategoriesList(filteredSubs),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesList(List<CategoryModel> categories) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No categories found', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            ElevatedButton(
              onPressed: () => _showCategoryDialog(),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF064E26)),
              child: const Text('Create First Category', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final subCount = cat.subcategories.length;

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail / Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Color(int.tryParse(cat.colorHex?.replaceAll('#', '0xFF') ?? '0xFFE8F5E9') ?? 0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: cat.imageUrl != null && cat.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            cat.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, color: Color(0xFF064E26)),
                          ),
                        )
                      : const Icon(Icons.category_rounded, color: Color(0xFF064E26), size: 26),
                ),
                const SizedBox(width: 14),

                // Name & Meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            cat.name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          if (!cat.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'HIDDEN',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Slug: ${cat.slug}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$subCount subcategories',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E26)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Order: ${cat.displayOrder}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Active Switch
                Tooltip(
                  message: cat.isActive ? 'Active (Click to hide from store)' : 'Hidden (Click to show in store)',
                  child: Switch.adaptive(
                    value: cat.isActive,
                    activeColor: const Color(0xFF0C8340),
                    onChanged: (val) => _toggleCategoryActive(cat, val),
                  ),
                ),

                // Actions: Edit & Delete
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF064E26)),
                  tooltip: 'Edit Category',
                  onPressed: () => _showCategoryDialog(category: cat),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                  tooltip: 'Delete Category',
                  onPressed: () => _confirmDeleteCategory(cat),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubcategoriesList(List<SubcategoryModel> subcategories) {
    return Column(
      children: [
        // Category Filter Dropdown Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text('Filter by Parent Category:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedCategoryFilter,
                hint: const Text('All Categories'),
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Categories')),
                  ..._categories.map((c) {
                    return DropdownMenuItem(value: c.id, child: Text(c.name));
                  }),
                ],
                onChanged: (val) {
                  setState(() => _selectedCategoryFilter = val);
                },
              ),
            ],
          ),
        ),

        // Subcategory List
        Expanded(
          child: subcategories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_tree_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('No subcategories found', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 6),
                      ElevatedButton(
                        onPressed: () => _showSubcategoryDialog(),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF064E26)),
                        child: const Text('Add Subcategory', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: subcategories.length,
                  itemBuilder: (context, index) {
                    final sub = subcategories[index];
                    final parentName = _getParentCategoryName(sub.categoryId);

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Thumbnail / Icon
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: sub.imageUrl != null && sub.imageUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        sub.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.subdirectory_arrow_right_rounded, color: Color(0xFF064E26)),
                                      ),
                                    )
                                  : const Icon(Icons.subdirectory_arrow_right_rounded, color: Color(0xFF064E26)),
                            ),
                            const SizedBox(width: 14),

                            // Name & Parent Category
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        sub.name,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      if (!sub.isActive)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'HIDDEN',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8F5E9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          parentName,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E26)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Slug: ${sub.slug}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Order: ${sub.displayOrder}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Active Switch
                            Tooltip(
                              message: sub.isActive ? 'Active (Click to hide)' : 'Hidden (Click to activate)',
                              child: Switch.adaptive(
                                value: sub.isActive,
                                activeColor: const Color(0xFF0C8340),
                                onChanged: (val) => _toggleSubcategoryActive(sub, val),
                              ),
                            ),

                            // Actions
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF064E26)),
                              tooltip: 'Edit Subcategory',
                              onPressed: () => _showSubcategoryDialog(subcategory: sub),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                              tooltip: 'Delete Subcategory',
                              onPressed: () => _confirmDeleteSubcategory(sub),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
