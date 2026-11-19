import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../models/category_model.dart';
import '../../../models/product_model.dart';
import '../../../models/banner_model.dart';
import '../../../models/cart_item_model.dart';
import '../../../services/mock_data_service.dart';
import '../../../shared_widgets/promo_banner_card.dart';
import '../../../shared_widgets/category_item.dart';
import '../../../shared_widgets/product_card.dart';
import '../../../shared_widgets/product_details_sheet.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../../../services/supabase_service.dart';
import '../../auth/screens/phone_login_screen.dart';
import 'category_products_screen.dart';
import 'search_screen.dart';
import '../widgets/storefront_chrome.dart';
import '../../../models/address_model.dart';
import '../../../models/delivery_area_model.dart';
import '../../../models/order_model.dart';
import '../../cart/widgets/cart_item_tile.dart';
import '../../cart/widgets/bill_details_card.dart';
import '../../cart/widgets/delivery_instructions_selector.dart';
import '../../address/screens/address_picker_sheet.dart';
import '../../order/screens/order_tracking_screen.dart';
import '../../order/widgets/order_card.dart';

/// Quick Basket Home Screen conforming to PRD Section 4.3
///
/// Hosts the five customer tabs (Home, Categories, Cart, Orders, Profile).
/// Phones/tablets get the mobile layout with a bottom navigation bar;
/// wide screens (>= 1024px) get the desktop storefront layout.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  final PageController _bannerController = PageController();
  int _activeBannerIndex = 0;
  Timer? _bannerTimer;

  // In-memory cart for state interaction
  final Map<String, CartItemModel> _cart = {};

  List<CategoryModel> _categories = MockDataService.categories;
  List<BannerModel> _banners = MockDataService.banners;
  List<ProductModel> _products = MockDataService.products;

  Map<String, dynamic>? _userProfile;
  StreamSubscription? _authSubscription;

  // Cart & Checkout State (PRD 4.8 & 4.9)
  static final AddressModel _defaultAddress = AddressModel(
    id: 'addr-500090-home',
    userId: 'guest-user',
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
  );
  AddressModel? _selectedAddress;
  List<AddressModel> _savedAddresses = [];
  ServiceabilityResult? _serviceabilityResult;
  bool get _isAddressServiceable => _serviceabilityResult?.isServiceable ?? true;
  int get _deliveryEtaMins => _serviceabilityResult?.estimatedMinutes ?? 11;
  final Set<String> _deliveryInstructions = {};
  double _tipAmount = 0.0;
  String? _appliedCoupon;
  double _couponDiscount = 0.0;
  final TextEditingController _couponController = TextEditingController();
  bool _isPlacingOrder = false;
  bool _checkoutOpen = false;
  String _paymentMethod = 'upi';

  // Orders State (PRD 4.10)
  List<OrderModel> _userOrders = [];
  bool _isLoadingOrders = false;
  Timer? _ordersSyncTimer;
  String _ordersFilter = 'all';

  // Categories tab search
  String _categoryQuery = '';

  // Profile preferences
  bool _notifyOrderUpdates = true;
  bool _notifyOffers = true;

  @override
  void initState() {
    super.initState();
    _selectedAddress = _defaultAddress;
    _evaluateServiceability();
    _loadData();
    _loadUserProfile();
    _loadUserOrders();
    _loadSavedAddresses();

    // Listen to real-time order state updates across tabs
    SupabaseService().ordersNotifier.addListener(_onOrdersNotifierChanged);
    SupabaseService().categoriesNotifier.addListener(_onCategoriesNotifierChanged);
    SupabaseService().hiddenProductIds.addListener(_onProductVisibilityChanged);
    SupabaseService().inventoryNotifier.addListener(_onInventoryChanged);
    SupabaseService().serviceabilityNotifier.addListener(_onServiceabilityChanged);

    // Cross-tab sync timer: periodically polls shared storage for real-time updates
    _ordersSyncTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (mounted) {
        SupabaseService().checkStockOverridesChanged();
        if (_currentNavIndex == 3) {
          _loadUserOrders(silent: true);
        } else if (_currentNavIndex == 0 || _currentNavIndex == 1) {
          _loadCategories(silent: true);
        }
      }
    });

    // Listen to Supabase Auth state changes
    final authStream = SupabaseService().authStateChanges;
    if (authStream != null) {
      _authSubscription = authStream.listen((_) {
        _loadUserProfile();
      });
    }

    // Auto-scroll promotional banners
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bannerController.hasClients && _banners.isNotEmpty) {
        final nextPage = (_activeBannerIndex + 1) % _banners.length;
        _bannerController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onOrdersNotifierChanged() {
    if (mounted) {
      _loadUserOrders(silent: true);
    }
  }

  void _onProductVisibilityChanged() {
    if (mounted) setState(() {});
  }

  void _onCategoriesNotifierChanged() {
    if (mounted) {
      _loadCategories(silent: true);
    }
  }

  void _onInventoryChanged() {
    if (mounted) {
      _loadData();
    }
  }

  void _onServiceabilityChanged() {
    if (mounted) {
      _evaluateServiceability();
    }
  }

  Future<void> _evaluateServiceability() async {
    final addr = _selectedAddress ?? _defaultAddress;
    final res = await SupabaseService().checkServiceability(
      pincode: addr.pincode,
      lat: addr.latitude,
      lng: addr.longitude,
      addressText: addr.formattedAddress,
    );
    if (mounted) {
      setState(() => _serviceabilityResult = res);
    }
  }

  Future<void> _loadCategories({bool silent = false}) async {
    final categories = await SupabaseService().getCategories();
    if (mounted) {
      setState(() => _categories = categories);
    }
  }

  Future<void> _loadUserProfile() async {
    final user = SupabaseService().currentUser;
    if (user != null) {
      final profile = await SupabaseService().getProfile(user.id);
      if (mounted) {
        setState(() => _userProfile = profile);
      }
    } else {
      if (mounted) {
        setState(() => _userProfile = null);
      }
    }
  }

  Future<void> _loadData() async {
    final categories = await SupabaseService().getCategories();
    final banners = await SupabaseService().getBanners();
    final products = await SupabaseService().getProducts();

    if (mounted) {
      setState(() {
        _categories = categories;
        _banners = banners;
        _products = products;

        // Synchronize in-memory cart with updated product stock
        _cart.removeWhere((prodId, item) {
          final p = _products.firstWhere(
            (prod) => prod.id == prodId || prod.name.toLowerCase() == item.product.name.toLowerCase(),
            orElse: () => item.product,
          );
          final v = p.variants.firstWhere(
            (varnt) => varnt.id == item.variant.id || varnt.unit.toLowerCase() == item.variant.unit.toLowerCase(),
            orElse: () => item.variant,
          );
          item.variant = v;
          if (v.isOutOfStock || v.stockQuantity <= 0) {
            return true;
          }
          if (item.quantity > v.stockQuantity) {
            item.quantity = v.stockQuantity;
          }
          return false;
        });
      });
    }
  }

  Future<void> _loadSavedAddresses() async {
    final userId = SupabaseService().currentUser?.id ?? 'guest-user';
    final addresses = await SupabaseService().getUserAddresses(userId);
    if (mounted) {
      setState(() {
        _savedAddresses = addresses;
        if (_selectedAddress == null && addresses.isNotEmpty) {
          _selectedAddress = addresses.first;
        }
      });
      _evaluateServiceability();
    }
  }

  bool _hasOrdersChanged(List<OrderModel> a, List<OrderModel> b) {
    if (a.length != b.length) return true;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].status != b[i].status) {
        return true;
      }
    }
    return false;
  }

  Future<void> _loadUserOrders({bool silent = false}) async {
    final user = SupabaseService().currentUser;
    final userId = user?.id ?? '00000000-0000-0000-0000-000000000000';
    if (!silent && mounted) {
      setState(() => _isLoadingOrders = true);
    }
    final orders = await SupabaseService().getUserOrders(userId);
    if (mounted) {
      final changed = _hasOrdersChanged(_userOrders, orders);
      if (changed || !silent) {
        setState(() {
          _userOrders = orders;
          _isLoadingOrders = false;
        });
      }
    }
  }

  void _reorderItems(OrderModel order) {
    int addedCount = 0;
    setState(() {
      for (final item in order.items) {
        if (item.variant.isOutOfStock || item.variant.stockQuantity <= 0) continue;
        final maxStock = item.variant.stockQuantity;
        if (_cart.containsKey(item.product.id)) {
          final current = _cart[item.product.id]!.quantity;
          _cart[item.product.id]!.quantity = (current + item.quantity).clamp(1, maxStock);
        } else {
          _cart[item.product.id] = CartItemModel(
            product: item.product,
            variant: item.variant,
            quantity: item.quantity.clamp(1, maxStock),
          );
        }
        addedCount++;
      }
      _checkoutOpen = false;
      _currentNavIndex = 2; // Switch directly to Cart tab
    });
    if (addedCount > 0) {
      _showCartSnackBar('$addedCount items added to your cart');
    } else {
      _showCartSnackBar('Items from this order are currently out of stock');
    }
  }

  @override
  void dispose() {
    SupabaseService().ordersNotifier.removeListener(_onOrdersNotifierChanged);
    SupabaseService().categoriesNotifier.removeListener(_onCategoriesNotifierChanged);
    SupabaseService().hiddenProductIds.removeListener(_onProductVisibilityChanged);
    SupabaseService().inventoryNotifier.removeListener(_onInventoryChanged);
    SupabaseService().serviceabilityNotifier.removeListener(_onServiceabilityChanged);
    _ordersSyncTimer?.cancel();
    _authSubscription?.cancel();
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Cart logic
  // ---------------------------------------------------------------------------

  int _getCartQuantity(String productId) {
    return _cart[productId]?.quantity ?? 0;
  }

  void _addToCart(ProductModel product, [ProductVariant? variant]) {
    final selectedVariant = variant ?? product.defaultVariant;
    if (selectedVariant.isOutOfStock || selectedVariant.stockQuantity <= 0) {
      _showCartSnackBar('${product.name} is currently out of stock');
      return;
    }
    setState(() {
      _cart[product.id] = CartItemModel(
        product: product,
        variant: selectedVariant,
        quantity: 1,
      );
    });
    _showCartSnackBar('${product.name} added to cart');
  }

  void _openCategoryProducts(CategoryModel category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryProductsScreen(
          category: category,
          allProducts: _visibleProducts,
          cart: _cart,
          onAddToCart: _addToCart,
          onIncrement: _incrementCart,
          onDecrement: _decrementCart,
          onViewCart: () => _goToTab(2),
          allCategories: _categories,
          addressLine: '$_addressLabel · $_addressLine',
          onNavigateTab: _goToTab,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          allProducts: _visibleProducts,
          cart: _cart,
          onAddToCart: _addToCart,
          onIncrement: _incrementCart,
          onDecrement: _decrementCart,
          onViewCart: () => _goToTab(2),
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _openProductDetails(ProductModel product) {
    ProductDetailsSheet.show(
      context,
      product: product,
      initialQuantity: _getCartQuantity(product.id),
      onAddToCart: _addToCart,
      onIncrement: (p, v) => _incrementCart(p.id),
      onDecrement: (p, v) => _decrementCart(p.id),
    ).then((_) => setState(() {}));
  }

  void _openTracking(OrderModel order) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: order)),
    ).then((_) {
      if (mounted) {
        _loadUserOrders(silent: true);
        _loadData();
      }
    });
  }

  void _onBannerTap(BannerModel banner) {
    if (_categories.isEmpty) return;
    final matchingCat = _categories.firstWhere(
      (c) => c.id == banner.categoryId,
      orElse: () => _categories.first,
    );
    _openCategoryProducts(matchingCat);
  }

  void _goToTab(int index) {
    setState(() {
      _currentNavIndex = index;
      if (index != 2) _checkoutOpen = false;
    });
    if (index == 3) _loadUserOrders();
    if (index == 2) _loadSavedAddresses();
  }

  void _incrementCart(String productId) {
    setState(() {
      final item = _cart[productId];
      if (item != null) {
        if (item.quantity < item.variant.stockQuantity) {
          item.quantity++;
        } else {
          _showCartSnackBar('Only ${item.variant.stockQuantity} units available for ${item.product.name}');
        }
      }
    });
  }

  void _decrementCart(String productId) {
    setState(() {
      final item = _cart[productId];
      if (item != null) {
        if (item.quantity > 1) {
          item.quantity--;
        } else {
          _cart.remove(productId);
          _showCartSnackBar('${item.product.name} removed from cart');
        }
      }
      if (_cart.isEmpty) _checkoutOpen = false;
    });
  }

  int get _totalCartItems => _cart.values.fold(0, (sum, item) => sum + item.quantity);

  double get _totalCartPrice => _cart.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get _itemTotal => _cart.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get _itemMrpTotal => _cart.values.fold(0.0, (sum, item) => sum + (item.variant.mrp * item.quantity));

  double get _deliveryFee {
    if (_cart.isEmpty) return 0.0;
    final freeThreshold = _serviceabilityResult?.freeDeliveryAbove ?? 199.0;
    if (_itemTotal >= freeThreshold) return 0.0;
    return _serviceabilityResult?.deliveryFee ?? 25.0;
  }

  double get _packagingFee => _cart.isEmpty ? 0.0 : 5.0;

  double get _grandTotal =>
      (_itemTotal + _deliveryFee + _packagingFee + _tipAmount - _couponDiscount).clamp(0.0, double.infinity);

  double get _cartSavings {
    final baseFee = _serviceabilityResult?.deliveryFee ?? 25.0;
    return (_itemMrpTotal - _itemTotal) + _couponDiscount + (_deliveryFee == 0 && _cart.isNotEmpty ? baseFee : 0);
  }

  void _applyCoupon() {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    if (code == 'WELCOME50') {
      if (_itemTotal < 150) {
        _showCartSnackBar('WELCOME50 requires a minimum order of ₹150');
        return;
      }
      setState(() {
        _appliedCoupon = 'WELCOME50';
        _couponDiscount = 50.0;
      });
      _showCartSnackBar('Coupon WELCOME50 applied! Saved ₹50');
    } else if (code == 'QUICK10') {
      setState(() {
        _appliedCoupon = 'QUICK10';
        _couponDiscount = (_itemTotal * 0.10).roundToDouble();
      });
      _showCartSnackBar('Coupon QUICK10 applied! Saved 10%');
    } else if (code == 'FREEDEL') {
      setState(() {
        _appliedCoupon = 'FREEDEL';
        _couponDiscount = _deliveryFee;
      });
      _showCartSnackBar('Coupon FREEDEL applied! Free delivery unlocked');
    } else {
      _showCartSnackBar('Invalid coupon code. Try WELCOME50 or QUICK10');
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponDiscount = 0.0;
      _couponController.clear();
    });
    _showCartSnackBar('Coupon removed');
  }

  Future<void> _selectDeliveryAddress() async {
    final user = SupabaseService().currentUser;
    final userId = user?.id ?? 'guest-user';
    final result = await AddressPickerSheet.show(
      context,
      currentAddress: _selectedAddress,
      userId: userId,
    );
    if (result != null) {
      setState(() => _selectedAddress = result);
      await _evaluateServiceability();
      _loadSavedAddresses();
    }
  }

  void _useCurrentLocation() {
    // Device GPS is simulated in this build: resolve to the default home address.
    setState(() => _selectedAddress = _savedAddresses.isNotEmpty ? _savedAddresses.first : _defaultAddress);
    _evaluateServiceability();
    _showCartSnackBar('Location updated: ${_selectedAddress!.areaStreet}');
  }

  void _openCheckout() {
    _selectedAddress ??= _defaultAddress;
    _loadSavedAddresses();
    _evaluateServiceability();
    setState(() => _checkoutOpen = true);
  }

  Future<void> _executeOrderPlacement(String paymentMethod) async {
    final effectiveAddress = _selectedAddress ?? _defaultAddress;
    final user = SupabaseService().currentUser;
    final userId = user?.id ?? '00000000-0000-0000-0000-000000000000';

    if (!_isAddressServiceable) {
      _showCartSnackBar('Delivery unavailable at ${effectiveAddress.pincode}. Please select an address in our delivery zone.');
      return;
    }

    final minOrder = _serviceabilityResult?.minOrderValue ?? 99.0;
    if (_itemTotal < minOrder) {
      _showCartSnackBar('Minimum order value for ${effectiveAddress.pincode} is ₹${minOrder.toStringAsFixed(0)}.');
      return;
    }

    setState(() => _isPlacingOrder = true);

    try {
      // Validate inventory before placing order: strictly block if item is out of stock or exceeds inventory
      final freshProducts = await SupabaseService().getProducts();
      for (final item in _cart.values) {
        final latestProduct = freshProducts.firstWhere(
          (p) => p.id == item.product.id || p.name.toLowerCase() == item.product.name.toLowerCase(),
          orElse: () => item.product,
        );
        final latestVariant = latestProduct.variants.firstWhere(
          (v) => v.id == item.variant.id || v.unit.toLowerCase() == item.variant.unit.toLowerCase(),
          orElse: () => item.variant,
        );
        if (latestVariant.isOutOfStock || latestVariant.stockQuantity <= 0) {
          setState(() {
            _isPlacingOrder = false;
            _cart.remove(item.product.id);
          });
          _showCartSnackBar('${item.product.name} is out of stock and was removed from your cart.');
          return;
        }
        if (item.quantity > latestVariant.stockQuantity) {
          setState(() {
            _isPlacingOrder = false;
            item.quantity = latestVariant.stockQuantity;
          });
          _showCartSnackBar('Only ${latestVariant.stockQuantity} units available for ${item.product.name}. Cart adjusted.');
          return;
        }
      }

      final cartItems = _cart.values
          .map((i) => CartItemModel(
                product: i.product,
                variant: i.variant,
                quantity: i.quantity,
              ))
          .toList();

      final order = await SupabaseService().createOrder(
        userId: userId,
        address: effectiveAddress,
        items: cartItems,
        itemTotal: _itemTotal,
        deliveryFee: _deliveryFee,
        packagingFee: _packagingFee,
        tipAmount: _tipAmount,
        couponDiscount: _couponDiscount,
        grandTotal: _grandTotal,
        paymentMethod: paymentMethod,
        deliveryInstructions: _deliveryInstructions.join(', '),
      );

      setState(() {
        _isPlacingOrder = false;
        _checkoutOpen = false;
        _cart.clear();
        _appliedCoupon = null;
        _couponDiscount = 0.0;
        _couponController.clear();
        _tipAmount = 0.0;
      });
      await _loadUserOrders();
      await _loadData();

      if (order != null && mounted) {
        _openTracking(order);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
        _showCartSnackBar('Order error: $e');
      }
    }
  }

  void _showCartSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: Responsive.isDesktop(context) ? 420 : null,
        backgroundColor: AppColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile helpers
  // ---------------------------------------------------------------------------

  void _showEditProfileDialog({
    required String userId,
    required String currentName,
    required String phone,
    String? currentEmail,
  }) {
    final nameController = TextEditingController(
      text: currentName == 'Quick Basket Customer' ? '' : currentName,
    );
    final emailController = TextEditingController(text: currentEmail ?? '');
    bool isSaving = false;
    String? dialogError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Edit Profile Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const Text('Update your name and email address',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 14),
                  if (dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(10)),
                      child: Text(dialogError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Full Name', hintText: 'Enter your full name'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email Address (Optional)', hintText: 'Enter your email'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.phone_android_rounded, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text('Phone: $phone', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final newName = nameController.text.trim();
                            if (newName.isEmpty) {
                              setModalState(() => dialogError = 'Please enter your name');
                              return;
                            }
                            setModalState(() {
                              isSaving = true;
                              dialogError = null;
                            });

                            try {
                              await SupabaseService().saveProfile(
                                userId: userId,
                                fullName: newName,
                                phoneNumber: phone,
                                email: emailController.text.trim(),
                              );
                              await _loadUserProfile();
                              if (!sheetContext.mounted) return;
                              Navigator.pop(sheetContext);
                              _showCartSnackBar('Profile updated successfully!');
                            } catch (e) {
                              setModalState(() {
                                isSaving = false;
                                dialogError = 'Failed to update: $e';
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Save Changes', style: TextStyle(fontSize: 15)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showNotificationSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Order updates', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Packing, rider and delivery alerts'),
                  value: _notifyOrderUpdates,
                  onChanged: (v) {
                    setState(() => _notifyOrderUpdates = v);
                    setSheetState(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Offers & deals', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Daily deals and coupon drops'),
                  value: _notifyOffers,
                  onChanged: (v) {
                    setState(() => _notifyOffers = v);
                    setSheetState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSupportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Help & 24/7 Support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('We usually respond within 2 minutes.', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              for (final opt in const [
                (Icons.chat_bubble_outline_rounded, 'Chat with us', 'Connecting you to a support agent…'),
                (Icons.call_outlined, 'Call support', 'Calling Quick Basket support…'),
                (Icons.mail_outline_rounded, 'Email us', 'Opening email to support@quickbasket.in…'),
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(opt.$1, color: AppColors.primary),
                  ),
                  title: Text(opt.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showCartSnackBar(opt.$3);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: AppStrings.appName,
      applicationVersion: 'v1.0.0',
      applicationIcon: const QbLogo(size: 40, showText: false),
      applicationLegalese: AppStrings.appTagline,
    );
  }

  Future<void> _logout() async {
    await SupabaseService().signOut();
    _loadUserProfile();
    _showCartSnackBar('Logged out successfully');
  }

  void _openLogin() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneLoginScreen()));
  }

  // ---------------------------------------------------------------------------
  // Derived data
  // ---------------------------------------------------------------------------

  String get _addressLabel => _selectedAddress?.type ?? 'Home';

  String get _addressLine {
    final a = _selectedAddress;
    if (a == null) return AppStrings.defaultAddress;
    return '${a.flatHouseNumber}, ${a.areaStreet}';
  }

  List<ProductModel> get _visibleProducts {
    final hidden = SupabaseService().hiddenProductIds.value;
    if (hidden.isEmpty) return _products;
    return _products.where((p) => !hidden.contains(p.id)).toList();
  }

  List<ProductModel> get _dealProducts {
    final list = _visibleProducts.where((p) => p.defaultVariant.discountPercentage > 0).toList()
      ..sort((a, b) => b.defaultVariant.discountPercentage.compareTo(a.defaultVariant.discountPercentage));
    return list.isEmpty ? _visibleProducts : list;
  }

  List<ProductModel> get _bestSellerProducts {
    final list = _visibleProducts.where((p) => p.isBestSeller).toList();
    return list.isEmpty ? _visibleProducts : list;
  }

  List<ProductModel> get _popularProducts {
    final list = _visibleProducts.where((p) => p.isFeatured).toList();
    return list.isEmpty ? _visibleProducts : list;
  }

  static const Map<String, int> _categoryGroupOf = {
    'eco': 0,
    'egg': 0,
    'grain': 0,
    'breakfast_dining': 0,
    'ramen_dining': 0,
    'coffee': 0,
    'fastfood': 1,
    'local_drink': 1,
    'cake': 1,
    'bakery_dining': 1,
    'spa': 2,
    'child_care': 2,
    'home': 2,
    'cleaning_services': 2,
    'pets': 2,
  };

  static const List<String> _categoryGroupTitles = [
    'Grocery & Kitchen',
    'Snacks & Drinks',
    'Home & Personal Care',
    'More to explore',
  ];

  List<(String, List<CategoryModel>)> get _groupedCategories {
    final q = _categoryQuery.trim().toLowerCase();
    final filtered = q.isEmpty ? _categories : _categories.where((c) => c.name.toLowerCase().contains(q)).toList();
    final groups = List.generate(_categoryGroupTitles.length, (_) => <CategoryModel>[]);
    for (final c in filtered) {
      groups[_categoryGroupOf[c.iconName] ?? 3].add(c);
    }
    return [
      for (var i = 0; i < groups.length; i++)
        if (groups[i].isNotEmpty) (_categoryGroupTitles[i], groups[i]),
    ];
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (Responsive.isDesktop(context)) return _buildDesktopScaffold();
    return _buildMobileScaffold();
  }

  // ======================= MOBILE / TABLET ===================================

  Widget _buildMobileScaffold() {
    final showCartBar = _totalCartItems > 0 && _currentNavIndex != 2;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                Expanded(child: _buildMobileTab()),
                if (showCartBar)
                  CartFloatingBar(
                    itemCount: _totalCartItems,
                    total: _totalCartPrice,
                    subtitle: _cartSavings > 0
                        ? 'You save ₹${_cartSavings.toStringAsFixed(0)} on this order'
                        : 'Free delivery above ₹199',
                    onTap: () => _goToTab(2),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: QbBottomNav(
        currentIndex: _currentNavIndex,
        cartCount: _totalCartItems,
        onTap: _goToTab,
      ),
    );
  }

  Widget _buildMobileTab() {
    switch (_currentNavIndex) {
      case 1:
        return _buildMobileCategoriesTab();
      case 2:
        return _checkoutOpen && _cart.isNotEmpty ? _buildMobileCheckout() : _buildMobileCartTab();
      case 3:
        return _buildOrdersTab();
      case 4:
        return _buildProfileTab();
      default:
        return _buildMobileHomeTab();
    }
  }

  Widget _buildMobileHomeTab() {
    final isTablet = Responsive.width(context) >= Responsive.tablet;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          MobileHomeHeader(
            addressLabel: _addressLabel,
            addressLine: _addressLine,
            deliveryMinutes: _deliveryEtaMins,
            isServiceable: _isAddressServiceable,
            onAddressTap: _selectDeliveryAddress,
            onProfileTap: () => _goToTab(4),
            onSearchTap: _openSearch,
          ),
          const SizedBox(height: 18),
          if (_banners.isNotEmpty) ...[
            _buildBannerCarousel(),
            const SizedBox(height: 18),
          ],
          _buildFreeDeliveryStrip(),
          const SizedBox(height: 22),
          QbSectionHeader(title: AppStrings.exploreCategories, onAction: () => _goToTab(1)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCategoryGrid(_categories.take(isTablet ? 12 : 8).toList(), columns: isTablet ? 6 : 4),
          ),
          const SizedBox(height: 22),
          QbSectionHeader(title: AppStrings.dealsAndDiscounts, onAction: () => _openFirstCategory()),
          const SizedBox(height: 8),
          _buildProductRail(_dealProducts),
          if (_banners.length > 1) ...[
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PromoSideCard(banner: _banners[1], onTap: () => _onBannerTap(_banners[1])),
            ),
          ],
          const SizedBox(height: 22),
          QbSectionHeader(title: AppStrings.bestSellers, onAction: () => _openFirstCategory()),
          const SizedBox(height: 8),
          _buildProductRail(_bestSellerProducts),
          const SizedBox(height: 22),
          QbSectionHeader(title: AppStrings.popularProducts, onAction: () => _openFirstCategory()),
          const SizedBox(height: 8),
          _buildProductRail(_popularProducts),
        ],
      ),
    );
  }

  void _openFirstCategory() {
    if (_categories.isNotEmpty) _openCategoryProducts(_categories.first);
  }

  Widget _buildBannerCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _bannerController,
            itemCount: _banners.length,
            onPageChanged: (index) => setState(() => _activeBannerIndex = index),
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PromoBannerCard(banner: banner, onTap: () => _onBannerTap(banner)),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (index) {
            final isActive = index == _activeBannerIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : const Color(0xFFC9D3CD),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFreeDeliveryStrip() {
    final freeThreshold = _serviceabilityResult?.freeDeliveryAbove ?? 199.0;
    final fee = _serviceabilityResult?.deliveryFee ?? 25.0;
    final shortfall = freeThreshold - _itemTotal;
    final unlocked = _cart.isNotEmpty && shortfall <= 0;
    final storeName = _serviceabilityResult?.matchedArea?.name ?? 'Nizampet Hub (500090)';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: !_isAddressServiceable
            ? const Color(0xFFFEF2F2)
            : (unlocked ? AppColors.primaryLight : AppColors.accentLight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: !_isAddressServiceable
              ? const Color(0xFFFECACA)
              : (unlocked ? const Color(0xFFCFE3D6) : AppColors.accentBorder),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: !_isAddressServiceable
                  ? const Color(0xFFDC2626)
                  : (unlocked ? AppColors.primary : AppColors.accent),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              !_isAddressServiceable
                  ? Icons.location_off_rounded
                  : (unlocked ? Icons.check_rounded : Icons.local_shipping_outlined),
              color: (!_isAddressServiceable || unlocked) ? Colors.white : AppColors.textPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  !_isAddressServiceable
                      ? (_serviceabilityResult?.statusHeadline ?? 'Delivery currently unavailable')
                      : (unlocked
                          ? 'You unlocked FREE delivery!'
                          : 'Free delivery on orders above ₹${freeThreshold.toStringAsFixed(0)}'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: !_isAddressServiceable ? const Color(0xFF991B1B) : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  !_isAddressServiceable
                      ? (_serviceabilityResult?.statusMessage ?? 'We are expanding to this pincode soon!')
                      : (_cart.isEmpty || unlocked
                          ? '₹${fee.toStringAsFixed(0)} delivery fee below · $storeName'
                          : 'Add ₹${shortfall.toStringAsFixed(0)} more to save the ₹${fee.toStringAsFixed(0)} fee'),
                  style: TextStyle(
                    fontSize: 12,
                    color: !_isAddressServiceable
                        ? const Color(0xFFB91C1C)
                        : (unlocked ? AppColors.primaryDeep : const Color(0xFF5B5133)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(List<CategoryModel> categories, {required int columns, double spacing = 10}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: categories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: 14,
            mainAxisExtent: itemWidth + 40,
          ),
          itemBuilder: (context, index) {
            final category = categories[index];
            return CategoryItem(
              category: category,
              size: null,
              onTap: () => _openCategoryProducts(category),
            );
          },
        );
      },
    );
  }

  Widget _buildProductRail(List<ProductModel> products) {
    return SizedBox(
      height: 270,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: products.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) => _productCard(products[index], width: 140),
      ),
    );
  }

  Widget _productCard(ProductModel product, {double? width, bool large = false}) {
    return ProductCard(
      product: product,
      width: width,
      large: large,
      cartQuantity: _getCartQuantity(product.id),
      onAddToCart: () => _addToCart(product),
      onIncrement: () => _incrementCart(product.id),
      onDecrement: () => _decrementCart(product.id),
      onTap: () => _openProductDetails(product),
    );
  }

  // ---------------------------- Categories ----------------------------------

  Widget _buildMobileCategoriesTab() {
    final isTablet = Responsive.width(context) >= Responsive.tablet;
    final groups = _groupedCategories;
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('All Categories',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                  ),
                  QbPill(
                    label: '12 mins',
                    icon: Icons.bolt_rounded,
                    background: AppColors.primaryLight,
                    foreground: AppColors.primary,
                    fontSize: 12,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _searchField(
                hint: 'Search across ${_categories.length} categories',
                onChanged: (v) => setState(() => _categoryQuery = v),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: groups.isEmpty
              ? const Center(child: Text('No categories match your search', style: TextStyle(color: AppColors.textSecondary)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  children: [
                    for (final g in groups) ...[
                      Text(g.$1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      _buildCategoryGrid(g.$2, columns: isTablet ? 6 : 4),
                      const SizedBox(height: 22),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _searchField({required String hint, required ValueChanged<String> onChanged}) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textBody),
        filled: true,
        fillColor: AppColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  // ------------------------------ Cart --------------------------------------

  Widget _mobileTopBar({
    required String title,
    VoidCallback? onBack,
    Widget? trailing,
  }) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(tooltip: 'Back', onPressed: onBack, icon: const Icon(Icons.chevron_left_rounded, size: 28))
          else
            const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          if (trailing != null) ...[trailing, const SizedBox(width: 8)],
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
              child: Icon(icon, size: 52, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _goToTab(0),
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('Start Shopping'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCartTab() {
    if (_cart.isEmpty) {
      return Column(
        children: [
          _mobileTopBar(title: 'My Cart', onBack: () => _goToTab(0)),
          Expanded(
            child: _buildEmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Your cart is empty',
              subtitle: 'Explore 1,000+ groceries delivered in 10–12 mins',
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _mobileTopBar(
          title: 'My Cart',
          onBack: () => _goToTab(0),
          trailing: _cartSavings > 0
              ? QbPill(
                  label: 'You save ₹${_cartSavings.toStringAsFixed(0)}',
                  background: AppColors.primaryLight,
                  foreground: AppColors.primary,
                  fontSize: 12,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                )
              : null,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _buildCartItemsCard(),
              const SizedBox(height: 12),
              _buildCouponSection(),
              const SizedBox(height: 12),
              DeliveryInstructionsSelector(
                selectedInstructions: _deliveryInstructions,
                onToggle: _toggleInstruction,
              ),
              const SizedBox(height: 12),
              BillDetailsCard(
                itemTotal: _itemTotal,
                itemMrpTotal: _itemMrpTotal,
                deliveryFee: _deliveryFee,
                packagingFee: _packagingFee,
                couponDiscount: _couponDiscount,
                tipAmount: _tipAmount,
                grandTotal: _grandTotal,
                onTipSelected: (tip) => setState(() => _tipAmount = tip),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Orders can be cancelled until they are packed. Refunds for cancelled prepaid orders are processed to the original payment method.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        _buildCartStickyFooter(),
      ],
    );
  }

  void _toggleInstruction(String instr) {
    setState(() {
      if (_deliveryInstructions.contains(instr)) {
        _deliveryInstructions.remove(instr);
      } else {
        _deliveryInstructions.add(instr);
      }
    });
  }

  Widget _buildCartItemsCard() {
    final freeThreshold = _serviceabilityResult?.freeDeliveryAbove ?? 199.0;
    final freeShortfall = freeThreshold - _itemTotal;
    final etaText = _isAddressServiceable ? 'Delivery in $_deliveryEtaMins minutes' : 'Delivery Not Available';
    final subText = !_isAddressServiceable
        ? (_serviceabilityResult?.statusHeadline ?? 'Location outside delivery area')
        : (freeShortfall > 0
            ? 'Shipment of $_totalCartItems items · add ₹${freeShortfall.toStringAsFixed(0)} for free delivery'
            : 'Shipment of $_totalCartItems items · free delivery unlocked');

    return Container(
      decoration: qbCard(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isAddressServiceable ? AppColors.primaryLight : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isAddressServiceable ? Icons.bolt_rounded : Icons.location_off_rounded,
                    color: _isAddressServiceable ? AppColors.primary : const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        etaText,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _isAddressServiceable ? null : const Color(0xFF991B1B),
                        ),
                      ),
                      Text(
                        subText,
                        style: TextStyle(
                          fontSize: 12,
                          color: _isAddressServiceable ? AppColors.textSecondary : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ..._cart.values.map(
            (item) => CartItemTile(
              item: item,
              onIncrement: () => _incrementCart(item.product.id),
              onDecrement: () => _decrementCart(item.product.id),
            ),
          ),
          InkWell(
            onTap: () => _goToTab(0),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Add more items',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
                  Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponSection({bool compact = false}) {
    if (_appliedCoupon != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(compact ? 12 : 18),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_offer_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$_appliedCoupon applied · saved ₹${_couponDiscount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primaryDeep),
              ),
            ),
            TextButton(
              onPressed: _removeCoupon,
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    final field = Row(
      children: [
        Expanded(
          child: TextField(
            controller: _couponController,
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => _applyCoupon(),
            decoration: InputDecoration(
              hintText: compact ? 'Coupon code' : 'Enter coupon (e.g. WELCOME50)',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: compact ? AppColors.primary : AppColors.borderStrong),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _applyCoupon,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryTint,
            foregroundColor: AppColors.primary,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('Apply'),
        ),
      ],
    );

    if (compact) return field;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: qbCard(borderColor: AppColors.primary, borderWidth: 1.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.local_offer_outlined, color: Color(0xFF946200), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Apply coupon', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Text('Try WELCOME50 · QUICK10 · FREEDEL',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          field,
        ],
      ),
    );
  }

  Widget _buildCartStickyFooter() {
    final minOrder = _serviceabilityResult?.minOrderValue ?? 99.0;
    final isBelowMinOrder = _itemTotal < minOrder;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF102818).withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isAddressServiceable)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_off_rounded, color: Color(0xFFDC2626), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _serviceabilityResult?.statusMessage ?? 'Quick Basket does not deliver to this pincode yet.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            )
          else if (isBelowMinOrder)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Minimum order value for this zone is ₹${minOrder.toStringAsFixed(0)}. Add ₹${(minOrder - _itemTotal).toStringAsFixed(0)} more to proceed.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Icon(
                _isAddressServiceable ? Icons.location_on_outlined : Icons.location_off_outlined,
                color: _isAddressServiceable ? AppColors.primary : const Color(0xFFDC2626),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: _addressLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _isAddressServiceable ? AppColors.textPrimary : const Color(0xFFDC2626),
                      ),
                    ),
                    TextSpan(text: ' · $_addressLine'),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textBody),
                ),
              ),
              TextButton(
                onPressed: _selectDeliveryAddress,
                child: const Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _greenTotalButton(
            total: _grandTotal,
            label: !_isAddressServiceable
                ? 'Delivery Unavailable'
                : (isBelowMinOrder ? 'Min order ₹${minOrder.toStringAsFixed(0)}' : 'Proceed to pay'),
            onPressed: (!_isAddressServiceable || isBelowMinOrder) ? null : _openCheckout,
          ),
        ],
      ),
    );
  }

  Widget _greenTotalButton({required double total, required String label, required VoidCallback? onPressed}) {
    return Material(
      color: onPressed == null ? AppColors.primary.withValues(alpha: 0.6) : AppColors.primary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    Text('TOTAL', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11)),
                  ],
                ),
                const Spacer(),
                if (_isPlacingOrder)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                else ...[
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------- Checkout ------------------------------------

  List<AddressModel> get _checkoutAddresses {
    final list = <AddressModel>[];
    final selected = _selectedAddress;
    if (selected != null) list.add(selected);
    for (final a in _savedAddresses) {
      if (!list.any((x) => x.id == a.id)) list.add(a);
    }
    return list;
  }

  static const List<(String, String, String, IconData, Color, Color)> _paymentOptions = [
    (
      'upi',
      'Instant Online Payment (UPI / Card)',
      'Google Pay, PhonePe, Paytm, Cards',
      Icons.account_balance_wallet_outlined,
      AppColors.infoLight,
      AppColors.info,
    ),
    (
      'cod',
      'Cash on Delivery (COD)',
      'Pay cash or UPI at the door to rider',
      Icons.payments_outlined,
      AppColors.accentLight,
      Color(0xFF946200),
    ),
  ];

  String get _paymentName => _paymentMethod == 'upi' ? 'UPI / Card' : 'Cash on Delivery';

  Widget _selectableCard({
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
    double radius = 16,
  }) {
    return Material(
      color: selected ? AppColors.primaryTint : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: selected ? AppColors.primary : const Color(0xFFE2E8E4), width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      ),
    );
  }

  IconData _addressIcon(String type) {
    switch (type.toLowerCase()) {
      case 'work':
        return Icons.work_outline_rounded;
      case 'home':
        return Icons.home_outlined;
      default:
        return Icons.location_on_outlined;
    }
  }

  Widget _addressCard(AddressModel a, {bool tall = false}) {
    final on = _selectedAddress?.id == a.id;
    final isAreaDeliverable = DarkStoreConfig.isPincodeDeliverable(a.pincode);

    return _selectableCard(
      selected: on,
      onTap: () {
        setState(() => _selectedAddress = a);
        _evaluateServiceability();
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: on
                  ? (isAreaDeliverable ? const Color(0xFFD4EEDC) : const Color(0xFFFEE2E2))
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isAreaDeliverable ? _addressIcon(a.type) : Icons.location_off_outlined,
              color: isAreaDeliverable ? AppColors.primary : const Color(0xFFDC2626),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(a.type, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    if (a.isDefault) ...[
                      const SizedBox(width: 6),
                      const QbPill(
                        label: 'DEFAULT',
                        background: AppColors.primaryLight,
                        foreground: AppColors.primaryDeep,
                        fontSize: 10,
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      ),
                    ],
                    const SizedBox(width: 6),
                    if (isAreaDeliverable)
                      QbPill(
                        label: '${DarkStoreConfig.getEstimatedMinutesForPincode(a.pincode)} MINS',
                        background: AppColors.primaryLight,
                        foreground: AppColors.primaryDeep,
                        fontSize: 9,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      )
                    else
                      const QbPill(
                        label: 'OUT OF ZONE',
                        background: Color(0xFFFEE2E2),
                        foreground: Color(0xFFDC2626),
                        fontSize: 9,
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  a.formattedAddress,
                  maxLines: tall ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textBody, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          QbRadioDot(selected: on),
        ],
      ),
    );
  }

  Widget _paymentCard((String, String, String, IconData, Color, Color) p) {
    final on = _paymentMethod == p.$1;
    return _selectableCard(
      selected: on,
      onTap: () => setState(() => _paymentMethod = p.$1),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: p.$5, borderRadius: BorderRadius.circular(12)),
            child: Icon(p.$4, color: p.$6, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(p.$3, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          QbRadioDot(selected: on),
        ],
      ),
    );
  }

  Widget _buildMobileCheckout() {
    return Column(
      children: [
        _mobileTopBar(
          title: 'Checkout',
          onBack: () => setState(() => _checkoutOpen = false),
          trailing: const Text('Step 2 of 2', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Deliver to', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                  TextButton.icon(
                    onPressed: _selectDeliveryAddress,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add new', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _useCurrentLocation,
                icon: const Icon(Icons.my_location_rounded, size: 18, color: AppColors.primary),
                label: const Row(
                  children: [
                    Expanded(
                      child: Text('Use current location',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    Text('GPS', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                  side: const BorderSide(color: Color(0xFFE2E8E4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              for (final a in _checkoutAddresses) ...[_addressCard(a), const SizedBox(height: 10)],
              const SizedBox(height: 4),
              const Text('Payment method', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              for (final p in _paymentOptions) ...[_paymentCard(p), const SizedBox(height: 10)],
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: qbCard(radius: 16),
                child: Column(
                  children: [
                    _summaryRow('$_totalCartItems items · Item total', '₹${_itemTotal.toStringAsFixed(0)}'),
                    const SizedBox(height: 8),
                    _summaryRow(
                      'Delivery · Packaging · Tip',
                      '${_deliveryFee == 0 ? 'FREE' : '₹${_deliveryFee.toStringAsFixed(0)}'} · ₹${_packagingFee.toStringAsFixed(0)} · ₹${_tipAmount.toStringAsFixed(0)}',
                    ),
                    if (_couponDiscount > 0) ...[
                      const SizedBox(height: 8),
                      _summaryRow('Coupon $_appliedCoupon', '−₹${_couponDiscount.toStringAsFixed(0)}'),
                    ],
                    const Divider(height: 20),
                    _summaryRow('Total to pay', '₹${_grandTotal.toStringAsFixed(0)}', bold: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(color: const Color(0xFF102818).withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Paying with '),
                  TextSpan(text: _paymentName, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const TextSpan(text: ' · Delivering to '),
                  TextSpan(text: _addressLabel, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ]),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              _placeOrderButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeOrderButton() {
    final hasOutOfStock = _cart.values.any((item) {
      final p = _products.firstWhere(
        (prod) => prod.id == item.product.id || prod.name.toLowerCase() == item.product.name.toLowerCase(),
        orElse: () => item.product,
      );
      final v = p.variants.firstWhere(
        (varnt) => varnt.id == item.variant.id || varnt.unit.toLowerCase() == item.variant.unit.toLowerCase(),
        orElse: () => item.variant,
      );
      return v.isOutOfStock || v.stockQuantity <= 0;
    });

    if (hasOutOfStock) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: const Color(0xFFF1F3F4),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        child: const Text('Items Out of Stock · Cannot Checkout', style: TextStyle(color: AppColors.error)),
      );
    }

    if (!_isAddressServiceable) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: const Color(0xFFFEE2E2),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        child: const Text('Unserviceable Location · Change Address', style: TextStyle(color: Color(0xFFDC2626))),
      );
    }

    final minOrder = _serviceabilityResult?.minOrderValue ?? 99.0;
    if (_itemTotal < minOrder) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: const Color(0xFFFEF3C7),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        child: Text('Min order is ₹${minOrder.toStringAsFixed(0)} · Add more',
            style: const TextStyle(color: Color(0xFFD97706))),
      );
    }

    return ElevatedButton(
      onPressed: _isPlacingOrder ? null : () => _executeOrderPlacement(_paymentMethod),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      child: _isPlacingOrder
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text('Place Order · ₹${_grandTotal.toStringAsFixed(0)}'),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: bold ? AppColors.textPrimary : AppColors.textBody,
            ),
          ),
        ),
        Text(value, style: TextStyle(fontSize: bold ? 15 : 13, fontWeight: FontWeight.w800)),
      ],
    );
  }

  // ------------------------------ Orders ------------------------------------

  List<OrderModel> get _filteredOrders {
    bool isActive(OrderModel o) => o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled;
    switch (_ordersFilter) {
      case 'active':
        return _userOrders.where(isActive).toList();
      case 'past':
        return _userOrders.where((o) => !isActive(o)).toList();
      default:
        return _userOrders;
    }
  }

  Widget _buildOrdersTab() {
    final desktop = Responsive.isDesktop(context);
    final header = Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(desktop ? 0 : 16, 16, desktop ? 0 : 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('My Orders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => _loadUserOrders(),
                icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              ),
            ],
          ),
          Row(
            children: [
              for (final t in const [('all', 'All orders'), ('active', 'Active'), ('past', 'Past')])
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: InkWell(
                    onTap: () => setState(() => _ordersFilter = t.$1),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _ordersFilter == t.$1 ? AppColors.primary : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        t.$2,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _ordersFilter == t.$1 ? FontWeight.w800 : FontWeight.w600,
                          color: _ordersFilter == t.$1 ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    Widget body;
    if (_isLoadingOrders) {
      body = const Center(child: CircularProgressIndicator(color: AppColors.primary));
    } else if (_userOrders.isEmpty) {
      body = _buildEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No orders yet',
        subtitle: 'When you place an order, it will appear here with live 12-min tracking and 1-click reorder.',
      );
    } else {
      final orders = _filteredOrders;
      body = RefreshIndicator(
        onRefresh: _loadUserOrders,
        color: AppColors.primary,
        child: orders.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('No orders in this list', style: TextStyle(color: AppColors.textSecondary))),
                ],
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(desktop ? 0 : 16, 14, desktop ? 0 : 16, 24),
                children: orders
                    .map((order) => OrderCard(
                          order: order,
                          onReorder: () => _reorderItems(order),
                          onTrack: () => _openTracking(order),
                        ))
                    .toList(),
              ),
      );
    }

    return Column(
      children: [
        if (desktop)
          Container(
            color: Colors.white,
            width: double.infinity,
            child: Center(
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: header),
            ),
          )
        else
          header,
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: desktop
              ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: body))
              : body,
        ),
      ],
    );
  }

  // ------------------------------ Profile -----------------------------------

  Widget _buildProfileTab() {
    final currentUser = SupabaseService().currentUser;
    final isGuest = currentUser == null;

    final fullName = _userProfile?['full_name'] as String? ?? 'Quick Basket Customer';
    final phone = _userProfile?['phone_number'] as String? ?? currentUser?.phone ?? '';
    final email = _userProfile?['email'] as String?;
    final initials = fullName
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    void editProfile() => _showEditProfileDialog(
          userId: currentUser!.id,
          currentName: fullName,
          phone: phone,
          currentEmail: email,
        );

    final menu = <(IconData, String, String, VoidCallback, bool)>[
      if (!isGuest) (Icons.person_outline_rounded, 'Edit Profile Details', 'Update your name and email address', editProfile, false),
      (Icons.location_on_outlined, 'Manage Addresses', '$_addressLabel · $_addressLine', _selectDeliveryAddress, false),
      (Icons.receipt_long_outlined, 'My Orders', 'Track, reorder and view bills', () => _goToTab(3), false),
      (Icons.notifications_none_rounded, 'Notifications', 'Order updates and offers', _showNotificationSettings, false),
      (Icons.headset_mic_outlined, 'Help & 24/7 Support', 'Chat with us about any order', _showSupportSheet, false),
      (Icons.info_outline_rounded, 'About Quick Basket', 'Terms, privacy and licences', _showAbout, false),
      (
        Icons.admin_panel_settings_outlined,
        'Store Staff Portal',
        'Restricted to authorized Store Managers',
        () => Navigator.pushNamed(context, '/admin'),
        true,
      ),
    ];

    final content = ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 54),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: isGuest
                    ? const Icon(Icons.person_outline_rounded, color: AppColors.primaryDark, size: 30)
                    : Text(initials.isEmpty ? 'QB' : initials,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isGuest ? 'Welcome to Quick Basket' : fullName,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isGuest
                          ? 'Log in for saved addresses & faster checkout'
                          : [phone, if (email != null && email.isNotEmpty) email].where((s) => s.isNotEmpty).join(' · '),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (!isGuest)
                Material(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Edit profile',
                    onPressed: editProfile,
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -34),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isGuest) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: qbCard(shadow: true),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Login or Sign Up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        const Text(
                          'Enter your phone number to access saved addresses, past orders, and enjoy faster checkout.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton(
                          onPressed: _openLogin,
                          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                          child: const Text('Login with Mobile Number', style: TextStyle(fontSize: 15)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    _profileQuickTile(Icons.receipt_long_outlined, 'Your orders', AppColors.primaryLight, AppColors.primary,
                        () => _goToTab(3)),
                    const SizedBox(width: 10),
                    _profileQuickTile(Icons.location_on_outlined, 'Addresses', AppColors.accentLight,
                        const Color(0xFF946200), _selectDeliveryAddress),
                    const SizedBox(width: 10),
                    _profileQuickTile(Icons.headset_mic_outlined, 'Support', AppColors.infoLight, AppColors.info,
                        _showSupportSheet),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: qbCard(),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < menu.length; i++)
                        InkWell(
                          onTap: menu[i].$4,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 60),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              border: i == menu.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: menu[i].$5 ? AppColors.primaryLight : AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(menu[i].$1, size: 20, color: menu[i].$5 ? AppColors.primaryDark : AppColors.textBody),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(menu[i].$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 1),
                                      Text(
                                        menu[i].$3,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  menu[i].$5 ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
                                  size: menu[i].$5 ? 16 : 22,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isGuest) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Log Out'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.errorBorder),
                      backgroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Center(
                  child: Text('Quick Basket v1.0.0', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (Responsive.isDesktop(context)) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(padding: const EdgeInsets.only(top: 24), child: content),
        ),
      );
    }
    return content;
  }

  Widget _profileQuickTile(IconData icon, String label, Color tint, Color ink, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: ink, size: 20),
                ),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================ DESKTOP ======================================

  Widget _buildDesktopScaffold() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          DesktopShopHeader(
            addressLine: '$_addressLabel · $_addressLine',
            deliveryMinutes: _deliveryEtaMins,
            isServiceable: _isAddressServiceable,
            onAddressTap: _selectDeliveryAddress,
            onSearchTap: _openSearch,
            onLogoTap: () => _goToTab(0),
            onOrdersTap: () => _goToTab(3),
            onAccountTap: () => _goToTab(4),
            onCartTap: () => _goToTab(2),
            cartCount: _totalCartItems,
            cartTotal: _totalCartPrice,
            categories: _categories,
            onCategoryTap: _openCategoryProducts,
            activeTab: _currentNavIndex,
          ),
          Expanded(child: _buildDesktopTab()),
        ],
      ),
    );
  }

  Widget _buildDesktopTab() {
    switch (_currentNavIndex) {
      case 1:
        return _buildDesktopCategoriesTab();
      case 2:
        return _buildDesktopCheckout();
      case 3:
        return _buildOrdersTab();
      case 4:
        return _buildProfileTab();
      default:
        return _buildDesktopHomeTab();
    }
  }

  Widget _desktopContainer({required Widget child, double maxWidth = 1320, EdgeInsets? padding}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding ?? const EdgeInsets.fromLTRB(32, 24, 32, 48), child: child),
      ),
    );
  }

  Widget _desktopProductGrid(List<ProductModel> products) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisExtent: 340,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, i) => _productCard(products[i], large: true),
    );
  }

  Widget _buildDesktopHomeTab() {
    final side1 = _banners.length > 1 ? _banners[1] : null;
    final side2 = _banners.length > 2 ? _banners[2] : null;

    return ListView(
      children: [
        _desktopContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_banners.isNotEmpty)
                SizedBox(
                  height: 300,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 2,
                        child: PromoBannerCard(banner: _banners.first, large: true, onTap: () => _onBannerTap(_banners.first)),
                      ),
                      if (side1 != null) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: PromoSideCard(banner: side1, onTap: () => _onBannerTap(side1))),
                              if (side2 != null) ...[
                                const SizedBox(height: 16),
                                Expanded(
                                  child: PromoSideCard(
                                    banner: side2,
                                    background: const Color(0xFFECE6F7),
                                    tagColor: const Color(0xFF5B3FA0),
                                    onTap: () => _onBannerTap(side2),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              Row(
                children: [
                  for (final p in const [
                    (Icons.bolt_rounded, 'Delivery in 12 minutes', 'From your nearest dark store'),
                    (Icons.local_shipping_outlined, 'Free delivery above ₹199', '₹25 delivery fee below that'),
                    (Icons.account_balance_wallet_outlined, 'Pay your way', 'UPI, cards or cash on delivery'),
                  ]) ...[
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: qbCard(radius: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                              child: Icon(p.$1, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                                  Text(p.$3, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (p.$2 != 'Pay your way') const SizedBox(width: 12),
                  ],
                ],
              ),
              const SizedBox(height: 32),
              QbSectionHeader(
                title: AppStrings.exploreCategories,
                actionLabel: 'See all ${_categories.length}',
                onAction: () => _goToTab(1),
                fontSize: 24,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 14),
              _desktopCategoryGrid(_categories.take(10).toList()),
              const SizedBox(height: 32),
              QbSectionHeader(
                title: AppStrings.dealsAndDiscounts,
                onAction: _openFirstCategory,
                fontSize: 24,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 14),
              _desktopProductGrid(_dealProducts.take(12).toList()),
              const SizedBox(height: 32),
              QbSectionHeader(
                title: AppStrings.bestSellers,
                onAction: _openFirstCategory,
                fontSize: 24,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 14),
              _desktopProductGrid(_bestSellerProducts.take(12).toList()),
              const SizedBox(height: 32),
              QbSectionHeader(
                title: AppStrings.popularProducts,
                onAction: _openFirstCategory,
                fontSize: 24,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 14),
              _desktopProductGrid(_popularProducts.take(12).toList()),
            ],
          ),
        ),
        DesktopFooter(onSupportTap: _showSupportSheet, onAboutTap: _showAbout),
      ],
    );
  }

  Widget _desktopCategoryGrid(List<CategoryModel> categories) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisExtent: 168,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, i) => CategoryItem(
        category: categories[i],
        size: null,
        radius: 22,
        fontSize: 13,
        onTap: () => _openCategoryProducts(categories[i]),
      ),
    );
  }

  Widget _buildDesktopCategoriesTab() {
    final groups = _groupedCategories;
    return ListView(
      children: [
        _desktopContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('All Categories', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                  ),
                  SizedBox(
                    width: 360,
                    child: _searchField(
                      hint: 'Search across ${_categories.length} categories',
                      onChanged: (v) => setState(() => _categoryQuery = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: Text('No categories match your search', style: TextStyle(color: AppColors.textSecondary))),
                ),
              for (final g in groups) ...[
                Text(g.$1, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                _desktopCategoryGrid(g.$2),
                const SizedBox(height: 28),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _desktopStep(int number, String title, Widget child, {Widget? action}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: qbCard(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('$number', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              ?action,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildDesktopCheckout() {
    if (_cart.isEmpty) {
      return _buildEmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Your cart is empty',
        subtitle: 'Explore 1,000+ groceries delivered in 10–12 mins',
      );
    }

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Checkout', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
            ),
            const QbPill(
              label: 'Secure checkout',
              icon: Icons.shield_outlined,
              background: AppColors.primaryLight,
              foreground: AppColors.primaryDeep,
              fontSize: 13,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: () => _goToTab(0),
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('Continue shopping'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _desktopStep(
          1,
          'Delivery address',
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 760 ? 3 : (constraints.maxWidth > 480 ? 2 : 1);
              final w = (constraints.maxWidth - (cols - 1) * 12) / cols;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final a in _checkoutAddresses) SizedBox(width: w, child: _addressCard(a, tall: true)),
                  SizedBox(
                    width: w,
                    child: OutlinedButton.icon(
                      onPressed: _useCurrentLocation,
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      label: const Text('Use current location'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: Color(0xFFE2E8E4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          action: TextButton(onPressed: _selectDeliveryAddress, child: const Text('+ Add new address')),
        ),
        const SizedBox(height: 18),
        _desktopStep(
          2,
          'Delivery instructions',
          DeliveryInstructionsSelector(
            selectedInstructions: _deliveryInstructions,
            onToggle: _toggleInstruction,
            chips: true,
          ),
        ),
        const SizedBox(height: 18),
        _desktopStep(
          3,
          'Payment method',
          Row(
            children: [
              Expanded(child: _paymentCard(_paymentOptions[0])),
              const SizedBox(width: 12),
              Expanded(child: _paymentCard(_paymentOptions[1])),
            ],
          ),
        ),
      ],
    );

    final summary = Container(
      padding: const EdgeInsets.all(22),
      decoration: qbCard(radius: 20, shadow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Your cart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              QbPill(
                label: _isAddressServiceable ? '$_deliveryEtaMins mins' : 'Out of Zone',
                icon: _isAddressServiceable ? Icons.bolt_rounded : Icons.location_off_rounded,
                background: _isAddressServiceable ? AppColors.primaryLight : const Color(0xFFFEE2E2),
                foreground: _isAddressServiceable ? AppColors.primaryDeep : const Color(0xFFDC2626),
                fontSize: 12,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._cart.values.map(
            (item) => CartItemTile(
              item: item,
              compact: true,
              showDivider: false,
              onIncrement: () => _incrementCart(item.product.id),
              onDecrement: () => _decrementCart(item.product.id),
            ),
          ),
          const SizedBox(height: 12),
          _buildCouponSection(compact: true),
          const SizedBox(height: 16),
          BillDetailsCard(
            embedded: true,
            itemTotal: _itemTotal,
            itemMrpTotal: _itemMrpTotal,
            deliveryFee: _deliveryFee,
            packagingFee: _packagingFee,
            couponDiscount: _couponDiscount,
            tipAmount: _tipAmount,
            grandTotal: _grandTotal,
            onTipSelected: (tip) => setState(() => _tipAmount = tip),
          ),
          const SizedBox(height: 16),
          _placeOrderButton(),
          const SizedBox(height: 8),
          Text(
            'Paying with $_paymentName · delivering to $_addressLabel',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );

    return ListView(
      children: [
        _desktopContainer(
          maxWidth: 1240,
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 48),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 940) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 20), summary]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 24),
                  SizedBox(width: 400, child: Padding(padding: const EdgeInsets.only(top: 58), child: summary)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
