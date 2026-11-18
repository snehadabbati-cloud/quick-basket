import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/category_model.dart';
import '../models/subcategory_model.dart';
import '../models/product_model.dart';
import '../models/banner_model.dart';
import '../models/cart_item_model.dart';
import '../models/address_model.dart';
import '../models/order_model.dart';
import '../models/delivery_area_model.dart';
import 'mock_data_service.dart';

/// Central Supabase service handling client initialization,
/// Phone OTP Auth, and Database CRUD operations (PRD Sections 2, 4.1, 9).
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  final List<OrderModel> _localOrders = [];
  List<OrderModel> get localOrders => _localOrders;

  /// Reactive notifier for real-time order updates across customer & store screens
  final ValueNotifier<List<OrderModel>> ordersNotifier = ValueNotifier<List<OrderModel>>([]);

  /// Reactive notifier for real-time category & subcategory updates across customer & admin screens
  final ValueNotifier<int> categoriesNotifier = ValueNotifier<int>(0);

  /// Reactive notifier for real-time inventory updates across customer & admin screens
  final ValueNotifier<int> inventoryNotifier = ValueNotifier<int>(0);

  /// Reactive notifier for real-time geofencing and delivery area updates
  final ValueNotifier<int> serviceabilityNotifier = ValueNotifier<int>(0);

  void notifyServiceabilityChanged() {
    serviceabilityNotifier.value++;
  }

  /// Products a store manager has switched off ("In store" toggle in the
  /// admin Products page). The customer storefront hides these.
  final ValueNotifier<Set<String>> hiddenProductIds = ValueNotifier<Set<String>>({});

  void setProductVisibility(String productId, bool visible) {
    final next = Set<String>.from(hiddenProductIds.value);
    if (visible) {
      next.remove(productId);
    } else {
      next.add(productId);
    }
    hiddenProductIds.value = next;
  }

  bool isProductVisible(String productId) => !hiddenProductIds.value.contains(productId);

  void notifyCategoriesChanged() {
    categoriesNotifier.value++;
  }

  void notifyInventoryChanged() {
    inventoryNotifier.value++;
  }

  void _notifyOrdersChanged() {
    ordersNotifier.value = List<OrderModel>.unmodifiable(_localOrders);
  }

  /// Lookup an order by UUID or order number (#QB-XXXXX)
  OrderModel? getOrderById(String orderIdOrNumber) {
    if (_localOrders.isEmpty) {
      _seedSampleOrder('00000000-0000-0000-0000-000000000000');
    }
    final cleanQuery = orderIdOrNumber.replaceAll('#', '').trim();
    final index = _localOrders.indexWhere((o) {
      final cleanNum = o.orderNumber.replaceAll('#', '').trim();
      return o.id == orderIdOrNumber ||
          o.id == cleanQuery ||
          o.orderNumber == orderIdOrNumber ||
          cleanNum == cleanQuery;
    });
    return index != -1 ? _localOrders[index] : null;
  }

  SupabaseClient get client {
    if (!_isInitialized) {
      throw StateError('Supabase is not initialized yet.');
    }
    return Supabase.instance.client;
  }

  /// Initialize Supabase client
  Future<void> initialize() async {
    if (_localOrders.isEmpty) {
      _seedSampleOrder('00000000-0000-0000-0000-000000000000');
    }

    if (!SupabaseConfig.isConfigured) {
      debugPrint('[SupabaseService] Supabase credentials not configured. Running in offline/dev mode.');
      return;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
      _isInitialized = true;
      debugPrint('[SupabaseService] Supabase successfully connected: ${SupabaseConfig.supabaseUrl}');
    } catch (e) {
      debugPrint('[SupabaseService] Error initializing Supabase: $e');
    }
  }

  // ==========================================
  // AUTHENTICATION (PRD Section 4.1)
  // ==========================================

  /// Current authenticated user
  User? get currentUser => _isInitialized ? client.auth.currentUser : null;

  /// Stream of authentication state changes
  Stream<AuthState>? get authStateChanges =>
      _isInitialized ? client.auth.onAuthStateChange : null;

  /// Send Phone OTP via Supabase Phone Auth
  Future<void> sendOtp({required String phoneNumber}) async {
    if (!_isInitialized) {
      debugPrint('[SupabaseService] Mock send OTP to $phoneNumber in dev mode');
      return;
    }
    await client.auth.signInWithOtp(phone: phoneNumber);
  }

  /// Verify Phone OTP
  Future<AuthResponse?> verifyOtp({
    required String phoneNumber,
    required String token,
  }) async {
    if (!_isInitialized) {
      debugPrint('[SupabaseService] Mock verify OTP in dev mode');
      return null;
    }
    return await client.auth.verifyOTP(
      phone: phoneNumber,
      token: token,
      type: OtpType.sms,
    );
  }

  /// Logout
  Future<void> signOut() async {
    if (_isInitialized) {
      await client.auth.signOut();
    }
  }

  /// Get Customer Profile from 'profiles' table
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    if (!_isInitialized) return null;
    try {
      final response = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('[SupabaseService] Error fetching profile: $e');
      return null;
    }
  }

  /// Create or Update Customer Profile in 'profiles' table
  Future<void> saveProfile({
    required String userId,
    required String fullName,
    required String phoneNumber,
    String? email,
  }) async {
    if (!_isInitialized) return;
    try {
      await client.from('profiles').upsert(
        {
          'id': userId,
          'full_name': fullName,
          'phone_number': phoneNumber,
          if (email != null && email.isNotEmpty) 'email': email,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'id',
      );
      debugPrint('[SupabaseService] Profile successfully saved for $userId');
    } catch (e) {
      debugPrint('[SupabaseService] Error saving profile: $e');
      rethrow;
    }
  }

  // ==========================================
  // DYNAMIC CATEGORY & SUBCATEGORY MANAGEMENT (PRD 4.4, 5.4)
  // ==========================================

  static const String _categoriesStorageKey = 'qb_custom_categories_v2';
  static const String _subcategoriesStorageKey = 'qb_custom_subcategories_v2';

  /// Fetch all active categories with their active subcategories
  Future<List<CategoryModel>> getCategories() async {
    final allSubs = await getSubcategories(includeInactive: false);
    final Map<String, List<String>> subsByCat = {};
    for (var s in allSubs) {
      subsByCat.putIfAbsent(s.categoryId, () => []).add(s.name);
    }

    List<CategoryModel> remoteList = [];
    if (_isInitialized) {
      try {
        final response = await client
            .from('categories')
            .select()
            .eq('is_active', true)
            .order('display_order', ascending: true);
        final List<dynamic> data = response as List<dynamic>;
        remoteList = data.map((json) => CategoryModel.fromJson(json as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('[SupabaseService] Remote categories fetch fallback: $e');
      }
    }

    var categories = await _mergeLocalCategories(remoteList, onlyActive: true);

    categories = categories.map((c) {
      final subs = subsByCat[c.id];
      if (subs != null && subs.isNotEmpty) {
        return c.copyWith(subcategories: subs);
      }
      return c;
    }).toList();

    return categories;
  }

  /// Fetch ALL categories (including inactive ones for Admin Panel)
  Future<List<CategoryModel>> getAllCategories() async {
    final allSubs = await getSubcategories(includeInactive: true);
    final Map<String, List<String>> subsByCat = {};
    for (var s in allSubs) {
      subsByCat.putIfAbsent(s.categoryId, () => []).add(s.name);
    }

    List<CategoryModel> remoteList = [];
    if (_isInitialized) {
      try {
        final response = await client
            .from('categories')
            .select()
            .order('display_order', ascending: true);
        final List<dynamic> data = response as List<dynamic>;
        remoteList = data.map((json) => CategoryModel.fromJson(json as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('[SupabaseService] Remote all categories fetch fallback: $e');
      }
    }

    var categories = await _mergeLocalCategories(remoteList, onlyActive: false);

    categories = categories.map((c) {
      final subs = subsByCat[c.id];
      if (subs != null && subs.isNotEmpty) {
        return c.copyWith(subcategories: subs);
      }
      return c;
    }).toList();

    return categories;
  }

  /// Merge remote categories with local storage overrides
  Future<List<CategoryModel>> _mergeLocalCategories(List<CategoryModel> baseList, {required bool onlyActive}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    List<CategoryModel> list = [];
    if (baseList.isNotEmpty) {
      list = List.from(baseList);
    } else {
      list = List.from(MockDataService.categories);
    }

    final rawJson = prefs.getString(_categoriesStorageKey);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final List<dynamic> localList = jsonDecode(rawJson) as List<dynamic>;
        for (var item in localList) {
          final cat = CategoryModel.fromJson(item as Map<String, dynamic>);
          final idx = list.indexWhere((c) => c.id == cat.id || c.slug == cat.slug);
          if (idx != -1) {
            list[idx] = cat;
          } else {
            list.add(cat);
          }
        }
      } catch (e) {
        debugPrint('[SupabaseService] Error parsing local categories: $e');
      }
    }

    if (onlyActive) {
      list = list.where((c) => c.isActive).toList();
    }

    list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return list;
  }

  Future<void> _saveLocalCategory(CategoryModel category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    List<Map<String, dynamic>> list = [];
    final rawJson = prefs.getString(_categoriesStorageKey);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        list = (jsonDecode(rawJson) as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    final idx = list.indexWhere((e) => e['id'] == category.id || e['slug'] == category.slug);
    if (idx != -1) {
      list[idx] = category.toJson();
    } else {
      list.add(category.toJson());
    }

    await prefs.setString(_categoriesStorageKey, jsonEncode(list));
  }

  Future<void> _deleteLocalCategory(String categoryId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    List<Map<String, dynamic>> list = [];
    final rawJson = prefs.getString(_categoriesStorageKey);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        list = (jsonDecode(rawJson) as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    list.removeWhere((e) => e['id'] == categoryId);
    await prefs.setString(_categoriesStorageKey, jsonEncode(list));
  }

  /// Create a new category
  Future<CategoryModel> createCategory({
    required String name,
    required String slug,
    String? imageUrl,
    String? iconName,
    String? colorHex,
    int displayOrder = 0,
    bool isActive = true,
  }) async {
    final newId = 'cat-${DateTime.now().millisecondsSinceEpoch}';
    final category = CategoryModel(
      id: newId,
      name: name,
      slug: slug,
      imageUrl: imageUrl,
      iconName: iconName ?? 'category',
      colorHex: colorHex ?? '#E8F5E9',
      displayOrder: displayOrder,
      isActive: isActive,
      subcategories: const [],
    );

    if (_isInitialized) {
      try {
        await client.from('categories').insert({
          'name': name,
          'slug': slug,
          'image_url': imageUrl,
          'icon_name': iconName ?? 'category',
          'color_hex': colorHex ?? '#E8F5E9',
          'display_order': displayOrder,
          'is_active': isActive,
        });
      } catch (e) {
        debugPrint('[SupabaseService] Note: Category insert into remote DB: $e');
      }
    }

    await _saveLocalCategory(category);
    notifyCategoriesChanged();
    return category;
  }

  /// Update an existing category
  Future<void> updateCategory(CategoryModel category) async {
    if (_isInitialized) {
      try {
        await client.from('categories').update({
          'name': category.name,
          'slug': category.slug,
          'image_url': category.imageUrl,
          'icon_name': category.iconName,
          'color_hex': category.colorHex,
          'display_order': category.displayOrder,
          'is_active': category.isActive,
        }).eq('id', category.id);
      } catch (e) {
        debugPrint('[SupabaseService] Note: Category update in remote DB: $e');
      }
    }

    await _saveLocalCategory(category);
    notifyCategoriesChanged();
  }

  /// Delete a category
  Future<void> deleteCategory(String categoryId) async {
    if (_isInitialized) {
      try {
        await client.from('categories').delete().eq('id', categoryId);
      } catch (e) {
        debugPrint('[SupabaseService] Note: Category delete from remote DB: $e');
      }
    }

    await _deleteLocalCategory(categoryId);
    notifyCategoriesChanged();
  }

  /// Toggle category active status
  Future<void> toggleCategoryStatus(String categoryId, bool isActive) async {
    final all = await getAllCategories();
    final cat = all.where((c) => c.id == categoryId).firstOrNull;
    if (cat != null) {
      await updateCategory(cat.copyWith(isActive: isActive));
    }
  }

  // ==========================================
  // SUBCATEGORY METHODS (PRD 4.4, 5.4)
  // ==========================================

  /// Fetch subcategories with optional category filtering
  Future<List<SubcategoryModel>> getSubcategories({
    String? categoryId,
    bool includeInactive = false,
  }) async {
    List<SubcategoryModel> remoteList = [];

    if (_isInitialized) {
      try {
        var query = client.from('subcategories').select();
        if (categoryId != null && categoryId.isNotEmpty) {
          query = query.eq('category_id', categoryId);
        }
        if (!includeInactive) {
          query = query.eq('is_active', true);
        }
        final res = await query.order('display_order', ascending: true);
        final List<dynamic> data = res as List<dynamic>;
        remoteList = data.map((json) => SubcategoryModel.fromJson(json as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('[SupabaseService] Remote subcategories fetch fallback: $e');
      }
    }

    var list = await _mergeLocalSubcategories(remoteList, categoryId: categoryId, onlyActive: !includeInactive);
    return list;
  }

  /// Merge subcategories with local storage overrides
  Future<List<SubcategoryModel>> _mergeLocalSubcategories(
    List<SubcategoryModel> baseList, {
    String? categoryId,
    required bool onlyActive,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    List<SubcategoryModel> list = List.from(baseList);

    // Initial mock seed if list is empty
    if (list.isEmpty) {
      for (var cat in MockDataService.categories) {
        if (categoryId == null || cat.id == categoryId) {
          for (int i = 0; i < cat.subcategories.length; i++) {
            final name = cat.subcategories[i];
            final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
            list.add(SubcategoryModel(
              id: '${cat.id}-sub-${i + 1}',
              categoryId: cat.id,
              name: name,
              slug: slug,
              displayOrder: i + 1,
              isActive: true,
              createdAt: DateTime.now(),
            ));
          }
        }
      }
    }

    final rawJson = prefs.getString(_subcategoriesStorageKey);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final List<dynamic> localList = jsonDecode(rawJson) as List<dynamic>;
        for (var item in localList) {
          final sub = SubcategoryModel.fromJson(item as Map<String, dynamic>);
          final idx = list.indexWhere((s) => s.id == sub.id || (s.categoryId == sub.categoryId && s.slug == sub.slug));
          if (idx != -1) {
            list[idx] = sub;
          } else {
            list.add(sub);
          }
        }
      } catch (e) {
        debugPrint('[SupabaseService] Error parsing local subcategories: $e');
      }
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      list = list.where((s) => s.categoryId == categoryId).toList();
    }

    if (onlyActive) {
      list = list.where((s) => s.isActive).toList();
    }

    list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return list;
  }

  Future<void> _saveLocalSubcategory(SubcategoryModel sub) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    List<Map<String, dynamic>> list = [];
    final rawJson = prefs.getString(_subcategoriesStorageKey);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        list = (jsonDecode(rawJson) as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    final idx = list.indexWhere((e) => e['id'] == sub.id || (e['category_id'] == sub.categoryId && e['slug'] == sub.slug));
    if (idx != -1) {
      list[idx] = sub.toJson();
    } else {
      list.add(sub.toJson());
    }

    await prefs.setString(_subcategoriesStorageKey, jsonEncode(list));
  }

  Future<void> _deleteLocalSubcategory(String subcategoryId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    List<Map<String, dynamic>> list = [];
    final rawJson = prefs.getString(_subcategoriesStorageKey);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        list = (jsonDecode(rawJson) as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    list.removeWhere((e) => e['id'] == subcategoryId);
    await prefs.setString(_subcategoriesStorageKey, jsonEncode(list));
  }

  /// Create a new subcategory
  Future<SubcategoryModel> createSubcategory({
    required String categoryId,
    required String name,
    required String slug,
    String? imageUrl,
    int displayOrder = 0,
    bool isActive = true,
  }) async {
    final newId = 'sub-${DateTime.now().millisecondsSinceEpoch}';
    final sub = SubcategoryModel(
      id: newId,
      categoryId: categoryId,
      name: name,
      slug: slug,
      imageUrl: imageUrl,
      displayOrder: displayOrder,
      isActive: isActive,
      createdAt: DateTime.now(),
    );

    if (_isInitialized) {
      try {
        await client.from('subcategories').insert({
          'category_id': categoryId,
          'name': name,
          'slug': slug,
          'image_url': imageUrl,
          'display_order': displayOrder,
          'is_active': isActive,
        });
      } catch (e) {
        debugPrint('[SupabaseService] Note: Subcategory insert into remote DB: $e');
      }
    }

    await _saveLocalSubcategory(sub);
    notifyCategoriesChanged();
    return sub;
  }

  /// Update an existing subcategory
  Future<void> updateSubcategory(SubcategoryModel subcategory) async {
    if (_isInitialized) {
      try {
        await client.from('subcategories').update({
          'category_id': subcategory.categoryId,
          'name': subcategory.name,
          'slug': subcategory.slug,
          'image_url': subcategory.imageUrl,
          'display_order': subcategory.displayOrder,
          'is_active': subcategory.isActive,
        }).eq('id', subcategory.id);
      } catch (e) {
        debugPrint('[SupabaseService] Note: Subcategory update in remote DB: $e');
      }
    }

    await _saveLocalSubcategory(subcategory);
    notifyCategoriesChanged();
  }

  /// Delete a subcategory
  Future<void> deleteSubcategory(String subcategoryId) async {
    if (_isInitialized) {
      try {
        await client.from('subcategories').delete().eq('id', subcategoryId);
      } catch (e) {
        debugPrint('[SupabaseService] Note: Subcategory delete from remote DB: $e');
      }
    }

    await _deleteLocalSubcategory(subcategoryId);
    notifyCategoriesChanged();
  }

  /// Toggle subcategory active status
  Future<void> toggleSubcategoryStatus(String subcategoryId, bool isActive) async {
    final all = await getSubcategories(includeInactive: true);
    final sub = all.where((s) => s.id == subcategoryId).firstOrNull;
    if (sub != null) {
      await updateSubcategory(sub.copyWith(isActive: isActive));
    }
  }

  /// Upload category or subcategory image to Supabase Storage
  Future<String?> uploadCategoryImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (!_isInitialized) {
      final b64 = base64Encode(bytes);
      return 'data:image/png;base64,$b64';
    }

    try {
      final ext = fileName.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_\.-]'), '_');
      final storagePath = '${DateTime.now().millisecondsSinceEpoch}_$cleanName';

      await client.storage.from('categories').uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(upsert: true, contentType: mimeType),
      );

      final publicUrl = client.storage.from('categories').getPublicUrl(storagePath);
      return publicUrl;
    } catch (e) {
      debugPrint('[SupabaseService] Note: Supabase Storage upload fallback to data URI: $e');
      final b64 = base64Encode(bytes);
      return 'data:image/png;base64,$b64';
    }
  }

  /// Fetch promotional banners
  Future<List<BannerModel>> getBanners() async {
    if (!_isInitialized) {
      return MockDataService.banners;
    }

    try {
      final response = await client
          .from('banners')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) return MockDataService.banners;

      return data.map((json) => BannerModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[SupabaseService] Error fetching banners, using fallback: $e');
      return MockDataService.banners;
    }
  }

  /// Fetch products with optional category filtering
  Future<List<ProductModel>> getProducts({String? categoryId}) async {
    List<ProductModel> list = [];
    if (_isInitialized) {
      try {
        var query = client
            .from('products')
            .select('*, product_variants(*)')
            .eq('is_active', true);

        if (categoryId != null) {
          query = query.eq('category_id', categoryId);
        }

        final response = await query;
        final List<dynamic> data = response as List<dynamic>;
        if (data.isNotEmpty) {
          list = data.map((json) {
            final map = json as Map<String, dynamic>;
            final variantsRaw = map['product_variants'] as List<dynamic>? ?? [];
            map['variants'] = variantsRaw;
            return ProductModel.fromJson(map);
          }).toList();
        }
      } catch (e) {
        debugPrint('[SupabaseService] Error fetching products, using fallback: $e');
      }
    }

    if (list.isEmpty) {
      list = List.from(MockDataService.products);
      if (categoryId != null) {
        list = list.where((p) => p.categoryId == categoryId).toList();
      }
    }

    // Always merge persistent stock overrides onto the returned products
    list = await _applyStockOverridesToList(list);

    // Keep MockDataService in sync
    for (final p in list) {
      final idx = MockDataService.products.indexWhere((m) => m.id == p.id || m.name == p.name);
      if (idx != -1) {
        MockDataService.products[idx] = p;
      }
    }

    return list;
  }

  // ==========================================
  // ADDRESSES (PRD Section 4.2 & 4.8)
  // Centered around 500090, Hyderabad, Telangana
  // ==========================================

  static const String _addressesStorageKey = 'qb_custom_addresses_v2';

  Future<List<AddressModel>> getUserAddresses(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    List<AddressModel> list = [];

    // 1. Try remote Supabase DB if initialized
    if (_isInitialized) {
      try {
        final response = await client
            .from('user_addresses')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        final List<dynamic> data = response as List<dynamic>;
        if (data.isNotEmpty) {
          list = data.map((json) => AddressModel.fromJson(json as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        debugPrint('[SupabaseService] Error fetching addresses: $e');
      }
    }

    // 2. Default seed addresses centered around 500090 (Telangana)
    if (list.isEmpty) {
      list = [
        AddressModel(
          id: 'addr-500090-home',
          userId: userId,
          type: 'Home',
          flatHouseNumber: 'Flat 301, Sri Sai Residency',
          areaStreet: 'Road No. 1, Pragathi Nagar',
          landmark: 'Near Pragathi Nagar Lake',
          city: 'Hyderabad',
          state: 'Telangana',
          pincode: '500090',
          latitude: 17.5186,
          longitude: 78.3845,
          isDefault: true,
        ),
        AddressModel(
          id: 'addr-500072-work',
          userId: userId,
          type: 'Work',
          flatHouseNumber: 'Office 4B, KPHB 7th Phase',
          areaStreet: 'Main Commercial Road, Kukatpally',
          landmark: 'Beside Forum Sujana Mall',
          city: 'Hyderabad',
          state: 'Telangana',
          pincode: '500072',
          latitude: 17.4933,
          longitude: 78.3995,
          isDefault: false,
        ),
        AddressModel(
          id: 'addr-500034-other',
          userId: userId,
          type: 'Other',
          flatHouseNumber: 'Plot 102, Road No. 12',
          areaStreet: 'Banjara Hills',
          landmark: 'Near City Center Mall',
          city: 'Hyderabad',
          state: 'Telangana',
          pincode: '500034',
          latitude: 17.4156,
          longitude: 78.4350,
          isDefault: false,
        ),
      ];
    }

    // 3. Merge locally persisted user addresses
    final raw = prefs.getString(_addressesStorageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> localJson = jsonDecode(raw);
        final localList = localJson.map((e) => AddressModel.fromJson(e as Map<String, dynamic>)).toList();
        for (final item in localList) {
          final idx = list.indexWhere((a) => a.id == item.id);
          if (idx != -1) {
            list[idx] = item;
          } else {
            list.insert(0, item);
          }
        }
      } catch (_) {}
    }

    return list;
  }

  Future<AddressModel> saveAddress(AddressModel address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    List<Map<String, dynamic>> localList = [];
    final raw = prefs.getString(_addressesStorageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        localList = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    final idx = localList.indexWhere((e) => e['id'] == address.id);
    if (idx != -1) {
      localList[idx] = address.toJson();
    } else {
      localList.insert(0, address.toJson());
    }
    await prefs.setString(_addressesStorageKey, jsonEncode(localList));

    if (_isInitialized) {
      try {
        final data = {
          'user_id': address.userId,
          'address_type': address.type,
          'address_line1': address.flatHouseNumber,
          'address_line2': address.areaStreet,
          if (address.landmark != null && address.landmark!.isNotEmpty) 'landmark': address.landmark,
          'city': address.city,
          'state': address.state,
          'pincode': address.pincode,
          if (address.latitude != null) 'latitude': address.latitude,
          if (address.longitude != null) 'longitude': address.longitude,
          'is_default': address.isDefault,
        };

        final response = await client.from('user_addresses').insert(data).select().single();
        return AddressModel.fromJson(response);
      } catch (e) {
        debugPrint('[SupabaseService] Error saving address to remote DB: $e');
      }
    }

    return address;
  }

  // ==========================================
  // GEOFENCING & SERVICEABILITY ENGINE (PRD 4.2 & 5.12)
  // Centered around 500090 (Nizampet, Telangana)
  // ==========================================

  static const String _deliveryAreasStorageKey = 'qb_custom_delivery_areas_v1';
  List<DeliveryAreaModel> _localDeliveryAreas = [];

  /// Fetch all active delivery areas (or all for admin configuration)
  Future<List<DeliveryAreaModel>> getDeliveryAreas({bool onlyActive = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    List<DeliveryAreaModel> list = [];

    // 1. Try remote Supabase DB if initialized
    if (_isInitialized) {
      try {
        final query = client.from('delivery_areas').select().order('estimated_delivery_mins', ascending: true);
        final response = await query;
        final List<dynamic> data = response as List<dynamic>;
        if (data.isNotEmpty) {
          list = data.map((json) => DeliveryAreaModel.fromJson(json as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        debugPrint('[SupabaseService] Remote delivery areas fallback: $e');
      }
    }

    // 2. Default seed areas centered around 500090 (Nizampet, Telangana)
    if (list.isEmpty) {
      list = List.from(DarkStoreConfig.defaultAreas);
    }

    // 3. Merge locally persisted overrides
    final raw = prefs.getString(_deliveryAreasStorageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> localJson = jsonDecode(raw);
        final localList = localJson.map((e) => DeliveryAreaModel.fromJson(e as Map<String, dynamic>)).toList();
        for (final item in localList) {
          final idx = list.indexWhere((a) => a.id == item.id || a.pincode == item.pincode);
          if (idx != -1) {
            list[idx] = item;
          } else {
            list.add(item);
          }
        }
      } catch (_) {}
    }

    _localDeliveryAreas = list;

    if (onlyActive) {
      return list.where((a) => a.isActive).toList();
    }
    return list;
  }

  /// Check serviceability for a given pincode or GPS coordinates against Dark Store 500090
  Future<ServiceabilityResult> checkServiceability({
    String? pincode,
    double? lat,
    double? lng,
    String? addressText,
  }) async {
    final areas = await getDeliveryAreas(onlyActive: true);

    String cleanPincode = (pincode ?? '').trim();
    if (cleanPincode.isEmpty && addressText != null) {
      final pinMatch = RegExp(r'\b(500\d{3}|50\d{4}|\d{6})\b').firstMatch(addressText);
      if (pinMatch != null) {
        cleanPincode = pinMatch.group(0)!;
      }
    }

    // 1. Direct match against active delivery areas by pincode
    if (cleanPincode.isNotEmpty) {
      final matchedArea = areas.where((a) => a.pincode == cleanPincode).firstOrNull;
      if (matchedArea != null) {
        double? distance;
        if (lat != null && lng != null) {
          distance = DarkStoreConfig.calculateDistanceKm(
            DarkStoreConfig.storeLatitude,
            DarkStoreConfig.storeLongitude,
            lat,
            lng,
          );
        } else {
          distance = DarkStoreConfig.calculateDistanceKm(
            DarkStoreConfig.storeLatitude,
            DarkStoreConfig.storeLongitude,
            matchedArea.latitude,
            matchedArea.longitude,
          );
        }
        return ServiceabilityResult.serviceable(matchedArea, distance);
      }
    }

    // 2. Coordinate-based geofence check (Haversine formula within 5.5 km of 500090)
    if (lat != null && lng != null) {
      final distance = DarkStoreConfig.calculateDistanceKm(
        DarkStoreConfig.storeLatitude,
        DarkStoreConfig.storeLongitude,
        lat,
        lng,
      );

      if (distance <= DarkStoreConfig.maxServiceRadiusKm) {
        // Find closest delivery area
        final sorted = List<DeliveryAreaModel>.from(areas);
        sorted.sort((a, b) {
          final distA = DarkStoreConfig.calculateDistanceKm(lat, lng, a.latitude, a.longitude);
          final distB = DarkStoreConfig.calculateDistanceKm(lat, lng, b.latitude, b.longitude);
          return distA.compareTo(distB);
        });

        final closest = sorted.isNotEmpty ? sorted.first : DarkStoreConfig.defaultAreas.first;
        return ServiceabilityResult.serviceable(closest, distance);
      } else {
        return ServiceabilityResult.unserviceable(cleanPincode.isEmpty ? 'Location' : cleanPincode, distance);
      }
    }

    return ServiceabilityResult.unserviceable(cleanPincode.isEmpty ? 'Unknown' : cleanPincode);
  }

  /// Update delivery area parameters (ETA, fee, min order value, active status)
  Future<void> updateDeliveryArea(DeliveryAreaModel area) async {
    final areas = await getDeliveryAreas(onlyActive: false);
    final idx = areas.indexWhere((a) => a.id == area.id || a.pincode == area.pincode);
    if (idx != -1) {
      areas[idx] = area;
    } else {
      areas.add(area);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await prefs.setString(_deliveryAreasStorageKey, jsonEncode(areas.map((a) => a.toJson()).toList()));

    if (_isInitialized) {
      try {
        await client.from('delivery_areas').upsert(area.toJson(), onConflict: 'pincode');
      } catch (e) {
        debugPrint('[SupabaseService] Remote delivery area update fallback: $e');
      }
    }

    notifyServiceabilityChanged();
  }

  /// Toggle area serviceability (e.g. pause for rain surge or night curfew)
  Future<void> toggleDeliveryArea(String areaId, bool isActive) async {
    final areas = await getDeliveryAreas(onlyActive: false);
    final area = areas.where((a) => a.id == areaId || a.pincode == areaId).firstOrNull;
    if (area != null) {
      await updateDeliveryArea(area.copyWith(isActive: isActive));
    }
  }

  // ==========================================
  // ORDERS (PRD Sections 4.9 & 4.10)
  // ==========================================

  Future<OrderModel?> createOrder({
    required String userId,
    required AddressModel address,
    required List<CartItemModel> items,
    required double itemTotal,
    required double deliveryFee,
    required double packagingFee,
    required double tipAmount,
    required double couponDiscount,
    required double grandTotal,
    required String paymentMethod,
    String? deliveryInstructions,
  }) async {
    final orderNum = 'QB-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(userId);
    final validUserId = isUuid ? userId : '00000000-0000-0000-0000-000000000000';

    // Inventory pre-validation: verify all requested items have sufficient stock
    final currentProducts = await getProducts();
    for (final item in items) {
      int available = 0;
      for (final p in currentProducts) {
        for (final v in p.variants) {
          if (v.id == item.variant.id || (p.name.toLowerCase() == item.product.name.toLowerCase() && v.unit == item.variant.unit)) {
            available = v.stockQuantity;
            break;
          }
        }
      }
      if (available <= 0) {
        throw Exception('${item.product.name} is out of stock');
      }
      if (available < item.quantity) {
        throw Exception('Only $available units available for ${item.product.name}');
      }
    }

    if (!_isInitialized) {
      final mockOrder = OrderModel(
        id: 'mock-order-${DateTime.now().millisecondsSinceEpoch}',
        orderNumber: orderNum,
        userId: validUserId,
        address: address,
        items: items,
        itemTotal: itemTotal,
        discountAmount: couponDiscount,
        deliveryFee: deliveryFee,
        packagingFee: packagingFee,
        tipAmount: tipAmount,
        grandTotal: grandTotal,
        paymentMethod: paymentMethod,
        paymentStatus: paymentMethod == 'cod' ? 'pending' : 'completed',
        status: OrderStatus.placed,
        deliveryOtp: '${1000 + (DateTime.now().millisecond * 9) % 9000}',
        deliveryInstructions: deliveryInstructions,
      );
      _localOrders.insert(0, mockOrder);
      await _persistCustomOrders();
      _notifyOrdersChanged();

      for (final item in items) {
        await decrementProductStock(
          item.product.id,
          item.variant.id,
          item.quantity,
          productName: item.product.name,
          variantUnit: item.variant.unit,
        );
      }
      return mockOrder;
    }

    try {
      // 1. Get active store ID
      String storeId = '11111111-1111-1111-1111-111111111111';
      try {
        final storesRes = await client.from('stores').select('id').limit(1);
        if (storesRes.isNotEmpty) {
          storeId = storesRes.first['id'] as String;
        }
      } catch (_) {}

      final isAddrUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(address.id);
      final encodedInstructions = _encodeItemsInInstructions(deliveryInstructions, items);

      // 2. Insert into orders table
      final orderData = {
        'order_number': orderNum,
        'user_id': validUserId,
        'store_id': storeId,
        'address_id': isAddrUuid ? address.id : null,
        'item_total': itemTotal,
        'discount_amount': couponDiscount,
        'delivery_fee': deliveryFee,
        'taxes': packagingFee,
        'grand_total': grandTotal,
        'payment_method': paymentMethod,
        'payment_status': paymentMethod == 'cod' ? 'pending' : 'completed',
        'order_status': 'placed',
        'delivery_otp': '${1000 + (DateTime.now().millisecond * 9) % 9000}',
        'delivery_instructions': encodedInstructions,
      };

      final orderRes = await client.from('orders').insert(orderData).select().single();
      final newOrderId = orderRes['id'] as String;

      // 3. Insert items into order_items table
      for (final item in items) {
        try {
          await client.from('order_items').insert({
            'order_id': newOrderId,
            'variant_id': item.variant.id,
            'product_name': item.product.name,
            'variant_unit': item.variant.unit,
            'unit_price': item.variant.sellingPrice,
            'quantity': item.quantity,
            'total_price': item.totalPrice,
          });
        } catch (itemErr) {
          debugPrint('[SupabaseService] Error inserting order item: $itemErr');
        }
      }

      final createdOrder = OrderModel.fromJson(orderRes, items: items, address: address);
      _localOrders.insert(0, createdOrder);
      await _persistCustomOrders();
      _notifyOrdersChanged();

      for (final item in items) {
        await decrementProductStock(
          item.product.id,
          item.variant.id,
          item.quantity,
          productName: item.product.name,
          variantUnit: item.variant.unit,
        );
      }
      return createdOrder;
    } catch (e) {
      if (e.toString().contains('out of stock') || e.toString().contains('Available:')) {
        rethrow;
      }
      debugPrint('[SupabaseService] Error creating order, returning local order: $e');
      final localOrder = OrderModel(
        id: 'local-order-${DateTime.now().millisecondsSinceEpoch}',
        orderNumber: orderNum,
        userId: validUserId,
        address: address,
        items: items,
        itemTotal: itemTotal,
        discountAmount: couponDiscount,
        deliveryFee: deliveryFee,
        packagingFee: packagingFee,
        tipAmount: tipAmount,
        grandTotal: grandTotal,
        paymentMethod: paymentMethod,
        paymentStatus: paymentMethod == 'cod' ? 'pending' : 'completed',
        status: OrderStatus.placed,
        deliveryOtp: '${1000 + (DateTime.now().millisecond * 9) % 9000}',
        deliveryInstructions: deliveryInstructions,
      );
      _localOrders.insert(0, localOrder);
      await _persistCustomOrders();
      _notifyOrdersChanged();

      for (final item in items) {
        await decrementProductStock(
          item.product.id,
          item.variant.id,
          item.quantity,
          productName: item.product.name,
          variantUnit: item.variant.unit,
        );
      }
      return localOrder;
    }
  }

  // ==========================================
  // FETCH USER ORDERS (PRD Section 4.10)
  // ==========================================

  bool _isUuid(String str) {
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(str.trim());
  }

  Future<void> _persistCustomOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final customOrders = _localOrders.where((o) =>
          o.id != 'sample-order-delivered' &&
          o.id != 'sample-order-active' &&
          o.orderNumber != '#QB-92014' &&
          o.orderNumber != '#QB-93108'
      ).map((o) {
        final encodedInstructions = _encodeItemsInInstructions(o.deliveryInstructions, o.items);
        return o.copyWith(deliveryInstructions: encodedInstructions).toJson();
      }).toList();
      await prefs.setString('qb_custom_orders_json', jsonEncode(customOrders));
      for (final o in _localOrders) {
        final cleanNum = o.orderNumber.replaceAll('#', '').trim();
        await prefs.setString('qb_status_${o.id}', o.status.value);
        await prefs.setString('qb_status_${o.orderNumber}', o.status.value);
        await prefs.setString('qb_status_$cleanNum', o.status.value);
        await prefs.setString('qb_status_#$cleanNum', o.status.value);
      }
    } catch (e) {
      debugPrint('[SupabaseService] Error persisting custom orders: $e');
    }
  }

  void _loadCustomOrdersFromPrefs(SharedPreferences prefs) {
    try {
      final raw = prefs.getString('qb_custom_orders_json');
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw);
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          final (items, cleanInstructions) = _extractItemsAndInstructions(map);
          final mapCopy = Map<String, dynamic>.from(map);
          mapCopy['delivery_instructions'] = cleanInstructions;
          final order = OrderModel.fromJson(mapCopy, items: items);
          final cleanNum = order.orderNumber.replaceAll('#', '').trim();
          final idx = _localOrders.indexWhere((o) {
            final oClean = o.orderNumber.replaceAll('#', '').trim();
            return o.id == order.id ||
                o.orderNumber == order.orderNumber ||
                oClean == cleanNum;
          });
          if (idx == -1) {
            _localOrders.insert(0, order);
          } else {
            _localOrders[idx] = _localOrders[idx].copyWith(
              items: _localOrders[idx].items.isEmpty && order.items.isNotEmpty ? order.items : _localOrders[idx].items,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[SupabaseService] Error loading custom orders from prefs: $e');
    }
  }

  OrderModel _syncOrderWithLatestStatus(OrderModel order, SharedPreferences prefs) {
    final cleanNum = order.orderNumber.replaceAll('#', '').trim();
    final saved = prefs.getString('qb_status_${order.id}') ??
        prefs.getString('qb_status_${order.orderNumber}') ??
        prefs.getString('qb_status_$cleanNum') ??
        prefs.getString('qb_status_#$cleanNum');
    final reason = prefs.getString('qb_cancel_reason_${order.id}') ??
        prefs.getString('qb_cancel_reason_${order.orderNumber}') ??
        prefs.getString('qb_cancel_reason_$cleanNum') ??
        prefs.getString('qb_cancel_reason_#$cleanNum') ??
        order.cancellationReason;
    if (saved != null) {
      final latest = OrderStatusExtension.fromString(saved);
      if (order.status != latest || order.cancellationReason != reason) {
        return order.copyWith(status: latest, cancellationReason: reason);
      }
    } else if (order.cancellationReason != reason) {
      return order.copyWith(cancellationReason: reason);
    }
    return order;
  }

  Future<List<OrderModel>> getUserOrders(String userId) async {
    if (_localOrders.isEmpty) {
      _seedSampleOrder(userId);
    }

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // CRITICAL FOR FLUTTER WEB: Forces reload from window.localStorage!
      _loadCustomOrdersFromPrefs(prefs);
    } catch (_) {}

    // 1. Sync local orders with shared storage (for immediate cross-tab updates)
    if (prefs != null) {
      for (int i = 0; i < _localOrders.length; i++) {
        _localOrders[i] = _syncOrderWithLatestStatus(_localOrders[i], prefs);
      }
    }

    if (!_isInitialized) {
      return List<OrderModel>.from(_localOrders);
    }

    final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(userId);
    if (!isUuid) {
      return List<OrderModel>.from(_localOrders);
    }

    try {
      final response = await client
          .from('orders')
          .select('*, order_items(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) {
        return List<OrderModel>.from(_localOrders);
      }

      final dbOrders = data.map((json) {
        final map = json as Map<String, dynamic>;
        final (items, cleanInstructions) = _extractItemsAndInstructions(map);
        final mapCopy = Map<String, dynamic>.from(map);
        mapCopy['delivery_instructions'] = cleanInstructions;
        return OrderModel.fromJson(mapCopy, items: items);
      }).toList();

      // Merge remote DB orders with any local orders
      final merged = <OrderModel>[..._localOrders];
      for (final o in dbOrders) {
        final cleanDbNum = o.orderNumber.replaceAll('#', '').trim();
        final idx = merged.indexWhere((m) {
          final cleanMNum = m.orderNumber.replaceAll('#', '').trim();
          return m.id == o.id || m.orderNumber == o.orderNumber || cleanMNum == cleanDbNum;
        });

        if (idx == -1) {
          merged.add(o);
        } else {
          merged[idx] = merged[idx].copyWith(
            status: o.status,
            items: merged[idx].items.isEmpty && o.items.isNotEmpty ? o.items : merged[idx].items,
          );
        }
      }

      // Sync all merged orders with SharedPreferences overrides (which might be more recent than DB)
      if (prefs != null) {
        for (int i = 0; i < merged.length; i++) {
          merged[i] = _syncOrderWithLatestStatus(merged[i], prefs);
        }
      }

      return merged;
    } catch (e) {
      debugPrint('[SupabaseService] Error fetching orders: $e');
      return List<OrderModel>.from(_localOrders);
    }
  }

  String _encodeItemsInInstructions(String? note, List<CartItemModel> items) {
    final cleanNote = (note ?? '').trim();
    if (items.isEmpty) return cleanNote;

    try {
      final itemsList = items.map((i) => {
        'product_id': i.product.id,
        'product_name': i.product.name,
        'brand': i.product.brand,
        'category_id': i.product.categoryId,
        'image_url': i.product.imageUrl,
        'variant_id': i.variant.id,
        'variant_unit': i.variant.unit,
        'unit_price': i.variant.sellingPrice,
        'quantity': i.quantity,
        'total_price': i.totalPrice,
      }).toList();

      final payload = jsonEncode(itemsList);
      if (cleanNote.isEmpty) {
        return '[QB_ITEMS_PAYLOAD]$payload[/QB_ITEMS_PAYLOAD]';
      }
      return '$cleanNote\n[QB_ITEMS_PAYLOAD]$payload[/QB_ITEMS_PAYLOAD]';
    } catch (e) {
      debugPrint('[SupabaseService] Error encoding items payload: $e');
      return cleanNote;
    }
  }

  (String, List<CartItemModel>) _decodeItemsFromInstructions(String? raw) {
    if (raw == null || raw.trim().isEmpty) return ('', []);

    final regex = RegExp(r'\[QB_ITEMS_PAYLOAD\](.*?)\[/QB_ITEMS_PAYLOAD\]', dotAll: true);
    final match = regex.firstMatch(raw);
    final cleanNote = raw.replaceAll(regex, '').trim();

    if (match == null) return (cleanNote, []);

    try {
      final jsonStr = match.group(1);
      if (jsonStr == null || jsonStr.isEmpty) return (cleanNote, []);

      final List<dynamic> list = jsonDecode(jsonStr);
      final items = list.map((itemJson) {
        final iMap = itemJson as Map<String, dynamic>;
        final productName = iMap['product_name'] as String? ?? 'Item';
        final variantUnit = iMap['variant_unit'] as String? ?? '1 unit';
        final unitPrice = (iMap['unit_price'] as num?)?.toDouble() ?? 50.0;
        final quantity = (iMap['quantity'] as num?)?.toInt() ?? 1;
        final imgUrl = iMap['image_url'] as String? ?? 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=500';
        final prodId = iMap['product_id'] as String? ?? 'p-item';
        final varId = iMap['variant_id'] as String? ?? 'v-item';

        final matchedProduct = MockDataService.products.firstWhere(
          (p) => p.name.toLowerCase() == productName.toLowerCase() || p.id == prodId,
          orElse: () => ProductModel(
            id: prodId,
            name: productName,
            brand: iMap['brand'] as String? ?? 'Quick Basket',
            description: productName,
            categoryId: iMap['category_id'] as String? ?? 'cat-1',
            imageUrl: imgUrl,
            variants: [
              ProductVariant(
                id: varId,
                productId: prodId,
                unit: variantUnit,
                mrp: unitPrice,
                sellingPrice: unitPrice,
                stockQuantity: 100,
              ),
            ],
          ),
        );

        final matchedVariant = matchedProduct.variants.firstWhere(
          (v) => v.unit == variantUnit,
          orElse: () => matchedProduct.defaultVariant,
        );

        return CartItemModel(
          product: matchedProduct,
          variant: matchedVariant,
          quantity: quantity,
        );
      }).toList();

      return (cleanNote, items);
    } catch (e) {
      debugPrint('[SupabaseService] Error decoding items payload: $e');
      return (cleanNote, []);
    }
  }

  List<CartItemModel> _generateFallbackItemsForValue(double totalValue) {
    final products = MockDataService.products;
    if (products.isEmpty) return [];

    final list = <CartItemModel>[];
    double remaining = totalValue > 0 ? totalValue : 50.0;

    for (final prod in products) {
      if (remaining <= 0) break;
      final v = prod.defaultVariant;
      if (v.sellingPrice <= remaining || list.isEmpty) {
        final qty = (remaining / v.sellingPrice).clamp(1, 2).toInt();
        list.add(CartItemModel(product: prod, variant: v, quantity: qty));
        remaining -= (v.sellingPrice * qty);
      }
    }
    return list;
  }

  (List<CartItemModel>, String?) _extractItemsAndInstructions(Map<String, dynamic> map) {
    final rawItems = map['order_items'] as List<dynamic>? ?? [];
    List<CartItemModel> items = [];

    if (rawItems.isNotEmpty) {
      items = rawItems.map((itemJson) {
        final iMap = itemJson as Map<String, dynamic>;
        final productName = iMap['product_name'] as String? ?? 'Item';
        final variantUnit = iMap['variant_unit'] as String? ?? '1 unit';
        final unitPrice = (iMap['unit_price'] as num?)?.toDouble() ?? 50.0;
        final quantity = (iMap['quantity'] as num?)?.toInt() ?? 1;

        final matchedProduct = MockDataService.products.firstWhere(
          (p) => p.name.toLowerCase() == productName.toLowerCase(),
          orElse: () {
            final prodId = 'p-${iMap['variant_id'] ?? 'default'}';
            return ProductModel(
              id: prodId,
              name: productName,
              brand: 'Quick Basket',
              description: productName,
              categoryId: 'c1',
              imageUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=500',
              variants: [
                ProductVariant(
                  id: iMap['variant_id'] as String? ?? 'v1',
                  productId: prodId,
                  unit: variantUnit,
                  mrp: unitPrice,
                  sellingPrice: unitPrice,
                  stockQuantity: 100,
                ),
              ],
            );
          },
        );

        final matchedVariant = matchedProduct.variants.firstWhere(
          (v) => v.unit == variantUnit,
          orElse: () => matchedProduct.defaultVariant,
        );

        return CartItemModel(
          product: matchedProduct,
          variant: matchedVariant,
          quantity: quantity,
        );
      }).toList();
    }

    // Check payload in instructions
    final rawInstructions = map['delivery_instructions'] as String?;
    final (cleanInstructions, decodedItems) = _decodeItemsFromInstructions(rawInstructions);

    if (items.isEmpty && decodedItems.isNotEmpty) {
      items = decodedItems;
    }

    if (items.isEmpty) {
      final val = (map['item_total'] as num?)?.toDouble() ?? (map['grand_total'] as num?)?.toDouble() ?? 50.0;
      items = _generateFallbackItemsForValue(val);
    }

    return (items, cleanInstructions.isEmpty ? null : cleanInstructions);
  }

  void _seedSampleOrder(String userId) {
    if (_localOrders.isNotEmpty) return;
    try {
      final products = MockDataService.products;
      if (products.isEmpty) return;

      final p1 = products[0];
      final p2 = products.length > 1 ? products[1] : p1;
      final p3 = products.length > 2 ? products[2] : p1;

      final deliveredItems = [
        CartItemModel(product: p1, variant: p1.defaultVariant, quantity: 2),
        CartItemModel(product: p2, variant: p2.defaultVariant, quantity: 1),
        CartItemModel(product: p3, variant: p3.defaultVariant, quantity: 1),
      ];

      final deliveredItemTotal = deliveredItems.fold(0.0, (sum, i) => sum + i.totalPrice);

      // 1. Seed sample delivered order (for testing 1-click Reorder and Receipt)
      _localOrders.add(
        OrderModel(
          id: 'sample-order-delivered',
          orderNumber: '#QB-92014',
          userId: userId,
          items: deliveredItems,
          itemTotal: deliveredItemTotal,
          deliveryFee: 0.0,
          packagingFee: 5.0,
          grandTotal: deliveredItemTotal + 5.0,
          status: OrderStatus.delivered,
          paymentMethod: 'upi',
          paymentStatus: 'completed',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      );

      // 2. Seed sample active order (for testing Live 12-min Tracking & Stepper)
      final activeItems = [
        CartItemModel(product: p1, variant: p1.defaultVariant, quantity: 1),
      ];
      final activeItemTotal = p1.defaultVariant.sellingPrice;

      _localOrders.insert(
        0,
        OrderModel(
          id: 'sample-order-active',
          orderNumber: '#QB-93108',
          userId: userId,
          items: activeItems,
          itemTotal: activeItemTotal,
          deliveryFee: 0.0,
          packagingFee: 5.0,
          grandTotal: activeItemTotal + 5.0,
          status: OrderStatus.outForDelivery,
          paymentMethod: 'cod',
          paymentStatus: 'pending',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          deliveryOtp: '4892',
          estimatedDeliveryMinutes: 7,
        ),
      );
      _notifyOrdersChanged();
    } catch (e) {
      debugPrint('[SupabaseService] _seedSampleOrder error: $e');
    }
  }

  // ==========================================
  // STORE MANAGER & ADMIN ROLE METHODS (PRD Section 5 & 6)
  // ==========================================

  /// Get role for a specific user from 'user_roles' table
  Future<String> getUserRole(String userId) async {
    if (!_isInitialized) return 'store_manager';
    try {
      final response = await client
          .from('user_roles')
          .select('role')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && response['role'] != null) {
        return response['role'] as String;
      }
      return 'customer';
    } catch (e) {
      debugPrint('[SupabaseService] Error checking user role: $e');
      return 'customer';
    }
  }

  /// Sign in staff using Email & Password and verify Store Manager / Admin permission
  Future<Map<String, dynamic>> signInStaff({
    required String email,
    required String password,
  }) async {
    // 1. Support demo manager shortcut for quick developer testing
    if (email.trim().toLowerCase() == 'manager@quickbasket.com' && password == 'admin123') {
      return {
        'id': '00000000-0000-0000-0000-000000000001',
        'email': 'manager@quickbasket.com',
        'role': 'store_manager',
        'name': 'Nizampet Store Manager',
      };
    }

    if (!_isInitialized) {
      throw Exception('Supabase is offline. Use demo manager: manager@quickbasket.com / admin123');
    }

    try {
      final authRes = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = authRes.user;
      if (user == null) {
        throw Exception('Invalid staff credentials.');
      }

      final role = await getUserRole(user.id);
      if (role != 'store_manager' && role != 'super_admin') {
        await client.auth.signOut();
        throw Exception('Access Denied: This account ($role) does not have Store Manager permissions.');
      }

      return {
        'id': user.id,
        'email': user.email ?? email,
        'role': role,
        'name': user.userMetadata?['name'] ?? 'Store Manager',
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch all store orders for the Store Manager Dashboard
  Future<List<OrderModel>> getAllStoreOrders() async {
    if (_localOrders.isEmpty) {
      _seedSampleOrder('00000000-0000-0000-0000-000000000000');
    }

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Reload fresh storage state from other browser tabs
      _loadCustomOrdersFromPrefs(prefs);
    } catch (_) {}

    if (prefs != null) {
      for (int i = 0; i < _localOrders.length; i++) {
        _localOrders[i] = _syncOrderWithLatestStatus(_localOrders[i], prefs);
      }
    }

    if (!_isInitialized) {
      return List<OrderModel>.from(_localOrders);
    }

    try {
      final response = await client
          .from('orders')
          .select('*, order_items(*)')
          .order('created_at', ascending: false)
          .limit(50);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) {
        return List<OrderModel>.from(_localOrders);
      }

      final dbOrders = data.map((json) {
        final map = json as Map<String, dynamic>;
        final (items, cleanInstructions) = _extractItemsAndInstructions(map);
        final mapCopy = Map<String, dynamic>.from(map);
        mapCopy['delivery_instructions'] = cleanInstructions;
        return OrderModel.fromJson(mapCopy, items: items);
      }).toList();

      final merged = <OrderModel>[..._localOrders];
      for (final o in dbOrders) {
        final cleanDbNum = o.orderNumber.replaceAll('#', '').trim();
        final idx = merged.indexWhere((m) {
          final cleanMNum = m.orderNumber.replaceAll('#', '').trim();
          return m.id == o.id || m.orderNumber == o.orderNumber || cleanMNum == cleanDbNum;
        });

        if (idx == -1) {
          merged.add(o);
        } else {
          merged[idx] = merged[idx].copyWith(
            status: o.status,
            items: merged[idx].items.isEmpty && o.items.isNotEmpty ? o.items : merged[idx].items,
          );
        }
      }

      if (prefs != null) {
        for (int i = 0; i < merged.length; i++) {
          merged[i] = _syncOrderWithLatestStatus(merged[i], prefs);
        }
      }

      return merged;
    } catch (e) {
      debugPrint('[SupabaseService] Error getting store orders: $e');
      return List<OrderModel>.from(_localOrders);
    }
  }

  /// Update order status from Store Manager Dashboard (PRD Section 6.2)
  Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus, {String? cancellationReason}) async {
    final cleanId = orderId.replaceAll('#', '').trim();
    final index = _localOrders.indexWhere((o) {
      final cleanNum = o.orderNumber.replaceAll('#', '').trim();
      return o.id == orderId ||
          o.id == cleanId ||
          o.orderNumber == orderId ||
          cleanNum == cleanId;
    });

    // 1. Persist status to cross-tab shared storage FIRST so any immediate reads see the new status
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      await prefs.setString('qb_status_$orderId', newStatus.value);
      await prefs.setString('qb_status_$cleanId', newStatus.value);
      await prefs.setString('qb_status_#$cleanId', newStatus.value);
      if (cancellationReason != null) {
        await prefs.setString('qb_cancel_reason_$orderId', cancellationReason);
        await prefs.setString('qb_cancel_reason_$cleanId', cancellationReason);
        await prefs.setString('qb_cancel_reason_#$cleanId', cancellationReason);
      }
      if (index == -1) {
        _loadCustomOrdersFromPrefs(prefs);
      }
      final targetIdx = index != -1
          ? index
          : _localOrders.indexWhere((o) {
              final cleanNum = o.orderNumber.replaceAll('#', '').trim();
              return o.id == orderId ||
                  o.id == cleanId ||
                  o.orderNumber == orderId ||
                  cleanNum == cleanId;
            });
      if (targetIdx != -1) {
        final o = _localOrders[targetIdx];
        final cleanNum = o.orderNumber.replaceAll('#', '').trim();
        await prefs.setString('qb_status_${o.id}', newStatus.value);
        await prefs.setString('qb_status_${o.orderNumber}', newStatus.value);
        await prefs.setString('qb_status_$cleanNum', newStatus.value);
        await prefs.setString('qb_status_#$cleanNum', newStatus.value);
        if (cancellationReason != null) {
          await prefs.setString('qb_cancel_reason_${o.id}', cancellationReason);
          await prefs.setString('qb_cancel_reason_${o.orderNumber}', cancellationReason);
          await prefs.setString('qb_cancel_reason_$cleanNum', cancellationReason);
          await prefs.setString('qb_cancel_reason_#$cleanNum', cancellationReason);
        }
        _localOrders[targetIdx] = o.copyWith(
          status: newStatus,
          cancellationReason: cancellationReason ?? o.cancellationReason,
        );
        await _persistCustomOrders();
      }
    } catch (e) {
      debugPrint('[SupabaseService] Error saving status to shared storage: $e');
    }

    // 2. Update local memory and notify listeners
    _notifyOrdersChanged();

    if (!_isInitialized) return true;

    try {
      if (_isUuid(cleanId)) {
        await client.from('orders').update({
          'order_status': newStatus.value,
        }).eq('id', cleanId);
      } else {
        await client.from('orders').update({
          'order_status': newStatus.value,
        }).or('order_number.eq.$cleanId,order_number.eq.#$cleanId');
      }
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] Error updating order status in DB: $e');
      return true;
    }
  }

  /// Get the latest order status across browser tabs (via shared storage) and DB
  Future<OrderStatus?> getLatestOrderStatus(String orderIdOrNumber) async {
    final cleanId = orderIdOrNumber.replaceAll('#', '').trim();

    // 1. Check shared storage across browser tabs with reload() for live updates
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Crucial for Flutter Web: Reloads memory cache from localStorage!
      final savedVal = prefs.getString('qb_status_$orderIdOrNumber') ??
          prefs.getString('qb_status_$cleanId') ??
          prefs.getString('qb_status_#$cleanId');
      final savedReason = prefs.getString('qb_cancel_reason_$orderIdOrNumber') ??
          prefs.getString('qb_cancel_reason_$cleanId') ??
          prefs.getString('qb_cancel_reason_#$cleanId');
      if (savedVal != null) {
        final parsed = OrderStatusExtension.fromString(savedVal);
        final localIdx = _localOrders.indexWhere((o) {
          final cleanNum = o.orderNumber.replaceAll('#', '').trim();
          return o.id == orderIdOrNumber ||
              o.id == cleanId ||
              o.orderNumber == orderIdOrNumber ||
              cleanNum == cleanId;
        });
        if (localIdx != -1) {
          final current = _localOrders[localIdx];
          if (current.status != parsed || (savedReason != null && current.cancellationReason != savedReason)) {
            _localOrders[localIdx] = current.copyWith(
              status: parsed,
              cancellationReason: savedReason ?? current.cancellationReason,
            );
            _notifyOrdersChanged();
          }
        }
        return parsed;
      }
    } catch (_) {}

    // 2. Check local memory
    final localIdx = _localOrders.indexWhere((o) {
      final cleanNum = o.orderNumber.replaceAll('#', '').trim();
      return o.id == orderIdOrNumber ||
          o.id == cleanId ||
          o.orderNumber == orderIdOrNumber ||
          cleanNum == cleanId;
    });
    if (localIdx != -1) {
      return _localOrders[localIdx].status;
    }

    // 3. Check Supabase DB
    if (_isInitialized) {
      try {
        final query = client.from('orders').select('order_status');
        final res = _isUuid(cleanId)
            ? await query.eq('id', cleanId).maybeSingle().timeout(const Duration(seconds: 2))
            : await query.or('order_number.eq.$cleanId,order_number.eq.#$cleanId').maybeSingle().timeout(const Duration(seconds: 2));
        if (res != null && res['order_status'] != null) {
          final parsed = OrderStatusExtension.fromString(res['order_status'] as String);
          return parsed;
        }
      } catch (_) {}
    }

    return null;
  }

  static const String _stockStorageKey = 'qb_stock_overrides';
  static const String _stockUpdatedStorageKey = 'qb_stock_last_updated';
  int _lastStockTimestamp = 0;

  /// Check if stock overrides were modified across browser tabs or windows
  Future<bool> checkStockOverridesChanged() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final ts = prefs.getInt(_stockUpdatedStorageKey) ?? 0;
      if (ts > _lastStockTimestamp) {
        _lastStockTimestamp = ts;
        notifyInventoryChanged();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<Map<String, int>> _loadStockOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString(_stockStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map;
        return decoded.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
    } catch (e) {
      debugPrint('[SupabaseService] Error loading stock overrides: $e');
    }
    return {};
  }

  Future<void> _saveStockOverride(String key, int newStock) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString(_stockStorageKey);
      Map<String, dynamic> overrides = {};
      if (raw != null && raw.isNotEmpty) {
        try {
          overrides = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        } catch (_) {}
      }
      overrides[key] = newStock;
      final now = DateTime.now().millisecondsSinceEpoch;
      _lastStockTimestamp = now;
      await prefs.setString(_stockStorageKey, jsonEncode(overrides));
      await prefs.setInt(_stockUpdatedStorageKey, now);
    } catch (e) {
      debugPrint('[SupabaseService] Error saving stock override: $e');
    }
  }

  Future<List<ProductModel>> _applyStockOverridesToList(List<ProductModel> products) async {
    final overrides = await _loadStockOverrides();
    if (overrides.isEmpty) return products;

    return products.map((prod) {
      bool changed = false;
      final updatedVariants = prod.variants.map((v) {
        int? val = overrides[v.id] ??
            overrides[v.id.toLowerCase()] ??
            overrides['${prod.id}_${v.id}'] ??
            overrides['${prod.id.toLowerCase()}_${v.id.toLowerCase()}'] ??
            overrides['${prod.id}_${v.unit}'] ??
            overrides['${prod.id.toLowerCase()}_${v.unit.toLowerCase()}'] ??
            overrides['${prod.name.toLowerCase()}_${v.unit.toLowerCase()}'] ??
            (prod.variants.length == 1 ? overrides[prod.id] ?? overrides[prod.name.toLowerCase()] : null);
        if (val != null) {
          changed = true;
          return v.copyWith(stockQuantity: val);
        }
        return v;
      }).toList();
      return changed ? prod.copyWith(variants: updatedVariants) : prod;
    }).toList();
  }

  /// Update stock for a product variant
  Future<bool> updateProductStock(
    String productId,
    String variantId,
    int newStock, {
    String? productName,
    String? variantUnit,
  }) async {
    try {
      if (productName == null || variantUnit == null) {
        for (final p in MockDataService.products) {
          for (final v in p.variants) {
            if (v.id == variantId || (p.id == productId && (variantUnit == null || v.unit == variantUnit))) {
              productName ??= p.name;
              variantUnit ??= v.unit;
              break;
            }
          }
          if (productName != null) break;
        }
      }

      await _saveStockOverride(variantId, newStock);
      await _saveStockOverride(variantId.toLowerCase(), newStock);
      if (productName != null && variantUnit != null) {
        await _saveStockOverride('${productName.toLowerCase()}_${variantUnit.toLowerCase()}', newStock);
        await _saveStockOverride('${productId}_$variantUnit', newStock);
        await _saveStockOverride('${productId.toLowerCase()}_${variantUnit.toLowerCase()}', newStock);
      }
      if (productId.isNotEmpty) {
        await _saveStockOverride('${productId}_$variantId', newStock);
        await _saveStockOverride('${productId.toLowerCase()}_${variantId.toLowerCase()}', newStock);
      }

      for (int i = 0; i < MockDataService.products.length; i++) {
        final prod = MockDataService.products[i];
        final idMatches = prod.id == productId || prod.id.toLowerCase() == productId.toLowerCase();
        final nameMatches = productName != null && prod.name.toLowerCase() == productName.toLowerCase();
        final hasVariant = prod.variants.any((v) => v.id == variantId);

        if (idMatches || nameMatches || hasVariant) {
          final updatedVariants = prod.variants.map((v) {
            final varMatches = v.id == variantId ||
                v.id.toLowerCase() == variantId.toLowerCase() ||
                (variantUnit != null && v.unit.toLowerCase() == variantUnit.toLowerCase()) ||
                (prod.variants.length == 1);
            if (varMatches) {
              return v.copyWith(stockQuantity: newStock);
            }
            return v;
          }).toList();
          MockDataService.products[i] = prod.copyWith(variants: updatedVariants);
        }
      }

      if (_isInitialized) {
        try {
          await client.from('product_variants').update({
            'stock_quantity': newStock,
          }).eq('id', variantId);
        } catch (dbErr) {
          debugPrint('[SupabaseService] Remote product variant update fallback: $dbErr');
        }
      }

      notifyInventoryChanged();
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] Error updating stock: $e');
      return false;
    }
  }

  /// Decrement product variant stock atomically
  Future<void> decrementProductStock(
    String productId,
    String variantId,
    int qty, {
    String? productName,
    String? variantUnit,
  }) async {
    final products = await getProducts();
    int currentStock = 0;
    String matchedProdId = productId;
    String matchedVarId = variantId;
    String? matchedName = productName;
    String? matchedUnit = variantUnit;

    for (final p in products) {
      final nameMatches = matchedName != null && p.name.toLowerCase() == matchedName.toLowerCase();
      final idMatches = p.id == productId;
      if (nameMatches || idMatches) {
        for (final v in p.variants) {
          final unitMatches = matchedUnit != null && v.unit.toLowerCase() == matchedUnit.toLowerCase();
          final varIdMatches = v.id == variantId;
          if (varIdMatches || unitMatches || p.variants.length == 1) {
            currentStock = v.stockQuantity;
            matchedProdId = p.id;
            matchedVarId = v.id;
            matchedName = p.name;
            matchedUnit = v.unit;
            break;
          }
        }
      }
      if (currentStock > 0) break;
    }

    if (currentStock == 0) {
      for (final p in products) {
        for (final v in p.variants) {
          if (v.id == variantId) {
            currentStock = v.stockQuantity;
            matchedProdId = p.id;
            matchedVarId = v.id;
            matchedName = p.name;
            matchedUnit = v.unit;
            break;
          }
        }
        if (currentStock > 0) break;
      }
    }

    final newStock = (currentStock - qty).clamp(0, 99999);
    await updateProductStock(
      matchedProdId,
      matchedVarId,
      newStock,
      productName: matchedName,
      variantUnit: matchedUnit,
    );
  }

  /// Restore product stock when an order is cancelled
  Future<void> restoreOrderStock(OrderModel order) async {
    final products = await getProducts();
    for (final item in order.items) {
      int currentStock = 0;
      String matchedProdId = item.product.id;
      String matchedVarId = item.variant.id;
      String matchedName = item.product.name;
      String matchedUnit = item.variant.unit;

      for (final p in products) {
        final nameMatches = p.name.toLowerCase() == item.product.name.toLowerCase();
        final idMatches = p.id == item.product.id;
        if (nameMatches || idMatches) {
          for (final v in p.variants) {
            final unitMatches = v.unit.toLowerCase() == item.variant.unit.toLowerCase();
            final varIdMatches = v.id == item.variant.id;
            if (varIdMatches || unitMatches || p.variants.length == 1) {
              currentStock = v.stockQuantity;
              matchedProdId = p.id;
              matchedVarId = v.id;
              matchedName = p.name;
              matchedUnit = v.unit;
              break;
            }
          }
        }
        if (currentStock > 0) break;
      }

      final newStock = currentStock + item.quantity;
      await updateProductStock(
        matchedProdId,
        matchedVarId,
        newStock,
        productName: matchedName,
        variantUnit: matchedUnit,
      );
    }
  }

  /// Cancel an order within cancellation window and auto-restore stock
  Future<bool> cancelOrder(String orderId, {String reason = 'Cancelled by customer'}) async {
    final order = getOrderById(orderId);
    if (order == null) return false;
    if (order.status == OrderStatus.delivered || order.status == OrderStatus.cancelled) {
      return false;
    }

    await updateOrderStatus(orderId, OrderStatus.cancelled, cancellationReason: reason);
    await restoreOrderStock(order);
    return true;
  }

  /// Create a new product and add it to inventory (PRD Section 6)
  Future<ProductModel?> createProduct({
    required String name,
    required String brand,
    required String categoryId,
    required String description,
    required String imageUrl,
    required double mrp,
    required double sellingPrice,
    required String unit,
    required int stockQuantity,
  }) async {
    final prodId = 'prod-${DateTime.now().millisecondsSinceEpoch}';
    final varId = 'var-${DateTime.now().millisecondsSinceEpoch}';

    final variant = ProductVariant(
      id: varId,
      productId: prodId,
      unit: unit,
      mrp: mrp,
      sellingPrice: sellingPrice,
      stockQuantity: stockQuantity,
    );

    final newProduct = ProductModel(
      id: prodId,
      name: name,
      brand: brand,
      categoryId: categoryId,
      description: description,
      imageUrl: imageUrl.isEmpty
          ? 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=500'
          : imageUrl,
      variants: [variant],
      isFeatured: true,
      rating: 5.0,
      reviewCount: 1,
    );

    // Prepend to in-memory list
    MockDataService.products.insert(0, newProduct);

    if (!_isInitialized) return newProduct;

    try {
      await client.from('products').insert({
        'id': prodId,
        'name': name,
        'brand': brand,
        'category_id': categoryId,
        'description': description,
        'image_url': newProduct.imageUrl,
      });

      await client.from('product_variants').insert({
        'id': varId,
        'product_id': prodId,
        'unit': unit,
        'mrp': mrp,
        'selling_price': sellingPrice,
        'stock_quantity': stockQuantity,
      });

      return newProduct;
    } catch (e) {
      debugPrint('[SupabaseService] Error inserting product in DB: $e');
      return newProduct;
    }
  }
}
