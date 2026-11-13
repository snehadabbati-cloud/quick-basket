import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/config/supabase_config.dart';
import '../../../models/category_model.dart';
import '../../../models/product_model.dart';
import '../../../models/banner_model.dart';
import '../../../models/cart_item_model.dart';
import '../../../services/mock_data_service.dart';
import '../../../shared_widgets/delivery_header.dart';
import '../../../shared_widgets/custom_search_bar.dart';
import '../../../shared_widgets/promo_banner_card.dart';
import '../../../shared_widgets/category_item.dart';
import '../../../shared_widgets/product_card.dart';
import '../../../shared_widgets/responsive_wrapper.dart';
import '../../../shared_widgets/product_details_sheet.dart';
import '../../../services/supabase_service.dart';
import '../../auth/screens/phone_login_screen.dart';
import 'category_products_screen.dart';
import 'search_screen.dart';
import '../../../models/address_model.dart';
import '../../../models/order_model.dart';
import '../../cart/widgets/cart_item_tile.dart';
import '../../cart/widgets/bill_details_card.dart';
import '../../cart/widgets/delivery_instructions_selector.dart';
import '../../address/screens/address_picker_sheet.dart';
import '../../order/screens/order_tracking_screen.dart';
import '../../order/widgets/order_card.dart';

/// Quick Basket Home Screen conforming to PRD Section 4.3
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
    id: 'default-home-1',
    userId: 'guest-user',
    type: 'Home',
    flatHouseNumber: 'Flat 402',
    areaStreet: 'Sunshine Apartments, 12th Main',
    landmark: 'Central Park',
    city: 'Bengaluru',
    pincode: '560001',
    isDefault: true,
  );
  AddressModel? _selectedAddress;
  final Set<String> _deliveryInstructions = {};
  double _tipAmount = 0.0;
  String? _appliedCoupon;
  double _couponDiscount = 0.0;
  final TextEditingController _couponController = TextEditingController();
  bool _isPlacingOrder = false;

  // Orders State (PRD 4.10)
  List<OrderModel> _userOrders = [];
  bool _isLoadingOrders = false;
  Timer? _ordersSyncTimer;

  @override
  void initState() {
    super.initState();
    _selectedAddress = _defaultAddress;
    _loadData();
    _loadUserProfile();
    _loadUserOrders();

    // Listen to real-time order state updates across tabs
    SupabaseService().ordersNotifier.addListener(_onOrdersNotifierChanged);
    SupabaseService().categoriesNotifier.addListener(_onCategoriesNotifierChanged);

    // Cross-tab sync timer: periodically polls shared storage for real-time updates
    _ordersSyncTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (mounted) {
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

  void _onCategoriesNotifierChanged() {
    if (mounted) {
      _loadCategories(silent: true);
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
      });
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
    setState(() {
      for (final item in order.items) {
        if (_cart.containsKey(item.product.id)) {
          _cart[item.product.id]!.quantity += item.quantity;
        } else {
          _cart[item.product.id] = CartItemModel(
            product: item.product,
            variant: item.variant,
            quantity: item.quantity,
          );
        }
      }
      _currentNavIndex = 2; // Switch directly to Cart tab
    });
    _showCartSnackBar('🎉 ${order.items.length} items added to basket!');
  }

  @override
  void dispose() {
    SupabaseService().ordersNotifier.removeListener(_onOrdersNotifierChanged);
    SupabaseService().categoriesNotifier.removeListener(_onCategoriesNotifierChanged);
    _ordersSyncTimer?.cancel();
    _authSubscription?.cancel();
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  int _getCartQuantity(String productId) {
    return _cart[productId]?.quantity ?? 0;
  }

  void _addToCart(ProductModel product, [ProductVariant? variant]) {
    setState(() {
      final selectedVariant = variant ?? product.defaultVariant;
      _cart[product.id] = CartItemModel(
        product: product,
        variant: selectedVariant,
        quantity: 1,
      );
    });
    _showCartSnackBar('${product.name} added to basket');
  }

  void _openCategoryProducts(CategoryModel category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryProductsScreen(
          category: category,
          allProducts: _products,
          cart: _cart,
          onAddToCart: _addToCart,
          onIncrement: _incrementCart,
          onDecrement: _decrementCart,
          onViewCart: () => setState(() => _currentNavIndex = 2),
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

  void _incrementCart(String productId) {
    setState(() {
      final item = _cart[productId];
      if (item != null) {
        if (item.quantity < item.variant.stockQuantity) {
          item.quantity++;
        } else {
          _showCartSnackBar('Max available stock reached');
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
    });
  }

  int get _totalCartItems =>
      _cart.values.fold(0, (sum, item) => sum + item.quantity);

  double get _totalCartPrice =>
      _cart.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get _itemTotal =>
      _cart.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get _itemMrpTotal =>
      _cart.values.fold(0.0, (sum, item) => sum + (item.variant.mrp * item.quantity));

  double get _deliveryFee =>
      (_itemTotal >= 199 || _cart.isEmpty) ? 0.0 : 25.0;

  double get _packagingFee => _cart.isEmpty ? 0.0 : 5.0;

  double get _grandTotal =>
      (_itemTotal + _deliveryFee + _packagingFee + _tipAmount - _couponDiscount).clamp(0.0, double.infinity);

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
      _showCartSnackBar('🎉 Coupon WELCOME50 applied! Saved ₹50');
    } else if (code == 'QUICK10') {
      setState(() {
        _appliedCoupon = 'QUICK10';
        _couponDiscount = (_itemTotal * 0.10).roundToDouble();
      });
      _showCartSnackBar('🎉 Coupon QUICK10 applied! Saved 10%');
    } else if (code == 'FREEDEL') {
      setState(() {
        _appliedCoupon = 'FREEDEL';
        _couponDiscount = _deliveryFee;
      });
      _showCartSnackBar('🎉 Coupon FREEDEL applied! Free Delivery unlocked');
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

  void _selectDeliveryAddress() async {
    final user = SupabaseService().currentUser;
    final userId = user?.id ?? 'guest-user';
    final result = await AddressPickerSheet.show(
      context,
      currentAddress: _selectedAddress,
      userId: userId,
    );
    if (result != null) {
      setState(() => _selectedAddress = result);
    }
  }

  void _promptCheckout() {
    _selectedAddress ??= _defaultAddress;
    _showPaymentOptionsSheet();
  }

  void _showPaymentOptionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Choose Payment Method',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(Icons.money_rounded, color: AppColors.primary),
                ),
                title: const Text('Cash on Delivery (COD)', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Pay cash or UPI at the door to rider'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(context);
                  _executeOrderPlacement('cod');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF3E0),
                  child: Icon(Icons.qr_code_scanner_rounded, color: AppColors.secondary),
                ),
                title: const Text('Instant Online Payment (UPI / Card)', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Google Pay, PhonePe, Paytm, Cards'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(context);
                  _executeOrderPlacement('upi');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _executeOrderPlacement(String paymentMethod) async {
    final effectiveAddress = _selectedAddress ?? _defaultAddress;
    final user = SupabaseService().currentUser;
    final userId = user?.id ?? '00000000-0000-0000-0000-000000000000';

    setState(() => _isPlacingOrder = true);

    try {
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
        _cart.clear();
        _appliedCoupon = null;
        _couponDiscount = 0.0;
        _tipAmount = 0.0;
      });
      await _loadUserOrders();

      if (order != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(order: order),
          ),
        ).then((_) {
          if (mounted) _loadUserOrders(silent: true);
        });
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
        backgroundColor: AppColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showLocationSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Delivery Location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(Icons.my_location, color: AppColors.primary),
                ),
                title: const Text('Use Current Location',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Using device GPS location'),
                onTap: () {
                  Navigator.pop(context);
                  _showCartSnackBar('Location updated: Green Valley, Block B');
                },
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.secondaryLight,
                  child: Icon(Icons.home, color: AppColors.secondary),
                ),
                title: const Text('Home (Default)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Flat 402, Block B, Green Valley'),
                trailing: const Icon(Icons.check_circle, color: AppColors.primary),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dialogError!,
                        style: const TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const Text('Full Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Enter your full name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Email Address (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      hintText: 'Enter your email',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.phone_android, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text('Phone: $phone', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
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
                                if (!mounted) return;
                                Navigator.pop(context);
                                _showCartSnackBar('Profile updated successfully!');
                              } catch (e) {
                                setModalState(() {
                                  isSaving = false;
                                  dialogError = 'Failed to update: $e';
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ResponsiveWrapper(
          child: Column(
            children: [
              // Only display Delivery Header, Search Bar and Banner on the Home tab (index 0)
              if (_currentNavIndex == 0) ...[
                DeliveryHeader(
                  onLocationTap: _showLocationSheet,
                  onProfileTap: () {
                    setState(() => _currentNavIndex = 4);
                  },
                  onAdminTap: () {
                    Navigator.pushNamed(context, '/admin');
                  },
                ),
                CustomSearchBar(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SearchScreen(
                          allProducts: _products,
                          cart: _cart,
                          onAddToCart: _addToCart,
                          onIncrement: _incrementCart,
                          onDecrement: _decrementCart,
                          onViewCart: () => setState(() => _currentNavIndex = 2),
                        ),
                      ),
                    ).then((_) => setState(() {}));
                  },
                ),
              ] else ...[
                // Top Header for non-home tabs
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Text(
                        _currentNavIndex == 1
                            ? 'All Categories'
                            : _currentNavIndex == 2
                                ? 'My Basket'
                                : _currentNavIndex == 3
                                    ? 'My Orders'
                                    : 'My Profile',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
              ],

              // Main Content Scrollable View
              Expanded(
                child: _buildCurrentTab(),
              ),

              // Floating Cart Checkout Bar (Appears when items are in cart and not on Cart tab)
              if (_totalCartItems > 0 && _currentNavIndex != 2)
                _buildCartFloatingBar(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentNavIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildCategoriesTab();
      case 2:
        return _buildCartTab();
      case 3:
        return _buildOrdersTab();
      case 4:
        return _buildProfileTab();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // 4. Promotional Banners Slider
        _buildBannerSlider(),

        const SizedBox(height: 16),

        // 5. Product Categories Section
        _buildSectionHeader(
          title: AppStrings.exploreCategories,
          onViewAll: () => setState(() => _currentNavIndex = 1),
        ),
        const SizedBox(height: 10),
        _buildCategoryGrid(),

        const SizedBox(height: 20),

        // 6. Popular Products Section
        _buildSectionHeader(
          title: AppStrings.popularProducts,
          badgeText: 'HOT',
          onViewAll: () {},
        ),
        const SizedBox(height: 10),
        _buildHorizontalProductRail(
          _products.where((p) => p.isFeatured).toList(),
        ),

        const SizedBox(height: 20),

        // 7. Best-Selling Products Section
        _buildSectionHeader(
          title: AppStrings.bestSellers,
          badgeText: 'TOP',
          onViewAll: () {},
        ),
        const SizedBox(height: 10),
        _buildHorizontalProductRail(
          _products.where((p) => p.isBestSeller).toList(),
        ),

        const SizedBox(height: 20),

        // 8. Daily Deals and Discounts
        _buildSectionHeader(
          title: AppStrings.dealsAndDiscounts,
          badgeText: 'SALE',
          onViewAll: () {},
        ),
        const SizedBox(height: 10),
        _buildHorizontalProductRail(
          _products,
        ),
      ],
    );
  }

  Widget _buildBannerSlider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 768;
        final bannerHeight = isDesktop ? 200.0 : 140.0;
        return Column(
          children: [
            SizedBox(
              height: bannerHeight,
              child: PageView.builder(
                controller: _bannerController,
                itemCount: _banners.length,
                onPageChanged: (index) {
                  setState(() => _activeBannerIndex = index);
                },
                itemBuilder: (context, index) {
                  final banner = _banners[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: InkWell(
                      onTap: () {
                        if (banner.categoryId != null) {
                          final matchingCat = _categories.firstWhere(
                            (c) => c.id == banner.categoryId,
                            orElse: () => _categories.first,
                          );
                          _openCategoryProducts(matchingCat);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: PromoBannerCard(banner: banner),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_banners.length, (index) {
                final isActive = index == _activeBannerIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 18 : 6,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? badgeText,
    VoidCallback? onViewAll,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (onViewAll != null)
            InkWell(
              onTap: onViewAll,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  AppStrings.viewAll,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    // Show top 8 categories on home page
    final displayCategories = _categories.take(8).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 768;
          final crossAxisCount = isDesktop ? 8 : 4;
          final availableWidth = constraints.maxWidth - ((crossAxisCount - 1) * 10);
          final itemWidth = availableWidth / crossAxisCount;
          // CategoryItem natural height is approx 102px (64px icon box + 6px gap + 32px 2-line text)
          final childAspectRatio = (itemWidth / 105).clamp(0.65, 1.4);

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayCategories.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final category = displayCategories[index];
              return CategoryItem(
                category: category,
                onTap: () => _openCategoryProducts(category),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHorizontalProductRail(List<ProductModel> products) {
    return SizedBox(
      height: 260,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: products.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final product = products[index];
          return ProductCard(
            product: product,
            cartQuantity: _getCartQuantity(product.id),
            onAddToCart: () => _addToCart(product),
            onIncrement: () => _incrementCart(product.id),
            onDecrement: () => _decrementCart(product.id),
            onTap: () => _openProductDetails(product),
          );
        },
      ),
    );
  }

  Widget _buildCartFloatingBar() {
    return Container(
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
              setState(() => _currentNavIndex = 2);
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
    );
  }

  Widget _buildCategoriesTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 768;
        if (isDesktop) {
          final crossAxisCount = constraints.maxWidth >= 1050 ? 3 : 2;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _categories.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 2.1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) => _buildCategoryCard(_categories[index]),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _categories.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _buildCategoryCard(_categories[index]),
        );
      },
    );
  }

  Widget _buildCategoryCard(CategoryModel cat) {
    final itemCount = _products.where((p) => p.categoryId == cat.id).length;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 0.8),
      ),
      child: InkWell(
        onTap: () => _openCategoryProducts(cat),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CategoryItem(category: cat),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$itemCount products available',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                ],
              ),
              if (cat.subcategories.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: cat.subcategories.take(4).map((sub) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        sub,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartTab() {
    if (_cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_basket_outlined, size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your basket is empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Explore 1,000+ groceries delivered in 10-12 mins',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => setState(() => _currentNavIndex = 0),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Start Shopping', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    final freeDeliveryShortfall = 199 - _itemTotal;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Delivery Address Header
              _buildCartAddressHeader(),

              const SizedBox(height: 12),

              // 2. Free Delivery Banner (PRD 4.8)
              _buildFreeDeliveryBanner(freeDeliveryShortfall),

              const SizedBox(height: 14),

              // 3. Items List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Items in Basket (${_cart.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _currentNavIndex = 0),
                    icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                    label: const Text(
                      'Add More Items',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._cart.values.map((item) {
                return CartItemTile(
                  item: item,
                  onIncrement: () => _incrementCart(item.product.id),
                  onDecrement: () => _decrementCart(item.product.id),
                );
              }),

              const SizedBox(height: 12),

              // 4. Delivery Instructions Chips (PRD 4.8)
              DeliveryInstructionsSelector(
                selectedInstructions: _deliveryInstructions,
                onToggle: (instr) {
                  setState(() {
                    if (_deliveryInstructions.contains(instr)) {
                      _deliveryInstructions.remove(instr);
                    } else {
                      _deliveryInstructions.add(instr);
                    }
                  });
                },
              ),

              const SizedBox(height: 14),

              // 5. Coupon Bar (PRD 4.8)
              _buildCouponSection(),

              const SizedBox(height: 14),

              // 6. Bill Details Card
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

              const SizedBox(height: 16),
            ],
          ),
        ),

        // Sticky Bottom Checkout Bar
        _buildCheckoutStickyBar(),
      ],
    );
  }

  Widget _buildCartAddressHeader() {
    final addr = _selectedAddress;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryLight,
            child: Icon(Icons.location_on_rounded, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  addr != null ? 'Delivering to ${addr.type}' : 'Deliver in 12 mins',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                Text(
                  addr != null ? addr.formattedAddress : 'Select delivery location',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _selectDeliveryAddress,
            child: Text(
              addr != null ? 'CHANGE' : 'SELECT',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeDeliveryBanner(double shortfall) {
    final isFree = shortfall <= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isFree ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFree ? const Color(0xFFA5D6A7) : const Color(0xFFFFE082),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isFree ? Icons.check_circle_rounded : Icons.local_shipping_outlined,
            size: 20,
            color: isFree ? AppColors.primary : const Color(0xFFF57F17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isFree
                  ? '🎉 You unlocked FREE 12-minute delivery!'
                  : 'Add ₹${shortfall.toStringAsFixed(0)} more to get FREE Delivery',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isFree ? AppColors.primary : const Color(0xFFE65100),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponSection() {
    if (_appliedCoupon != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.discount_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '$_appliedCoupon Applied (Saved ₹${_couponDiscount.toStringAsFixed(0)})',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary),
                ),
              ],
            ),
            TextButton(
              onPressed: _removeCoupon,
              child: const Text('REMOVE', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w800, fontSize: 11)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Enter coupon (e.g. WELCOME50)',
                    hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _applyCoupon,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('APPLY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Try: WELCOME50 (₹50 off) • QUICK10 (10% off) • FREEDEL',
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutStickyBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('TOTAL TO PAY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              Text(
                '₹${_grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: ElevatedButton(
              onPressed: _isPlacingOrder ? null : _promptCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isPlacingOrder
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Place Order', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        SizedBox(width: 6),
                        Icon(Icons.bolt_rounded, size: 20, color: Color(0xFFFFD700)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    if (_isLoadingOrders) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_userOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              const Text(
                'No past orders yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'When you place an order, it will appear here with live 12-min tracking and 1-click reorder.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => setState(() => _currentNavIndex = 0),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Start Shopping', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final activeOrders = _userOrders.where((o) => o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled).toList();

    return RefreshIndicator(
      onRefresh: _loadUserOrders,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Active order alert banner if any
          if (activeOrders.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0C8340), Color(0xFF075E2B)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFFFFD700), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Live Order in Progress!',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        Text(
                          '${activeOrders.first.orderNumber} • ${activeOrders.first.status.displayName}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderTrackingScreen(order: activeOrders.first),
                        ),
                      ).then((_) {
                        if (mounted) _loadUserOrders(silent: true);
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Track', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Past Orders (${_userOrders.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              TextButton.icon(
                onPressed: () => _loadUserOrders(),
                icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primary),
                label: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ..._userOrders.map((order) {
            return OrderCard(
              order: order,
              onReorder: () => _reorderItems(order),
              onTrack: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderTrackingScreen(order: order),
                  ),
                ).then((_) {
                  if (mounted) _loadUserOrders(silent: true);
                });
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final currentUser = SupabaseService().currentUser;
    final isGuest = currentUser == null;

    if (isGuest) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Login / Signup Card
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.person_outline_rounded, size: 36, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Login or Sign Up',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter your phone number to access saved addresses, past orders, and enjoy faster checkout.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Login with Mobile Number', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.headset_mic_outlined, color: AppColors.primary),
                  title: const Text('Help & 24/7 Support'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppColors.primary),
                  title: const Text('About Quick Basket'),
                  subtitle: const Text('v1.0.0 (PRD Architecture)'),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF064E26)),
                  title: const Text('Store Staff Portal'),
                  subtitle: const Text('Restricted to authorized Store Managers'),
                  trailing: const Icon(Icons.lock_outline_rounded, size: 14),
                  onTap: () => Navigator.pushNamed(context, '/admin'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final fullName = _userProfile?['full_name'] as String? ?? 'Quick Basket Customer';
    final phone = _userProfile?['phone_number'] as String? ?? currentUser.phone ?? '';
    final email = _userProfile?['email'] as String?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Stack(
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.person, size: 45, color: AppColors.primary),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            fullName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 2),
          Center(
            child: Text(
              phone,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        if (email != null && email.isNotEmpty) ...[
          const SizedBox(height: 2),
          Center(
            child: Text(
              email,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => _showEditProfileDialog(
              userId: currentUser.id,
              currentName: fullName,
              phone: phone,
              currentEmail: email,
            ),
            icon: const Icon(Icons.edit_outlined, size: 15, color: AppColors.primary),
            label: const Text(
              'Edit Profile',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
                title: const Text('Edit Profile Details'),
                subtitle: const Text('Update your name and email address'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => _showEditProfileDialog(
                  userId: currentUser.id,
                  currentName: fullName,
                  phone: phone,
                  currentEmail: email,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                title: const Text('Manage Addresses'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: _showLocationSheet,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
                title: const Text('My Orders'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => setState(() => _currentNavIndex = 3),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.notifications_outlined, color: AppColors.primary),
                title: const Text('Notifications'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.headset_mic_outlined, color: AppColors.primary),
                title: const Text('Help & 24/7 Support'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF064E26)),
                title: const Text('Store Staff Portal'),
                subtitle: const Text('Restricted to authorized Store Managers'),
                trailing: const Icon(Icons.lock_outline_rounded, size: 14),
                onTap: () => Navigator.pushNamed(context, '/admin'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                title: const Text('Log Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.error),
                onTap: () async {
                  await SupabaseService().signOut();
                  _loadUserProfile();
                  _showCartSnackBar('Logged out successfully');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() => _currentNavIndex = index);
          if (index == 3) {
            _loadUserOrders();
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        elevation: 0,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: AppStrings.navHome,
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view_rounded),
            label: AppStrings.navCategories,
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _totalCartItems > 0,
              label: Text('$_totalCartItems'),
              backgroundColor: AppColors.secondary,
              child: const Icon(Icons.shopping_basket_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: _totalCartItems > 0,
              label: Text('$_totalCartItems'),
              backgroundColor: AppColors.secondary,
              child: const Icon(Icons.shopping_basket_rounded),
            ),
            label: AppStrings.navCart,
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long_rounded),
            label: AppStrings.navOrders,
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: AppStrings.navProfile,
          ),
        ],
      ),
    ),
  ),
),
);
  }
}
