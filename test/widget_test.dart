import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_basket/main.dart';
import 'package:quick_basket/core/constants/app_strings.dart';
import 'package:quick_basket/features/home/screens/home_screen.dart';
import 'package:quick_basket/features/order/screens/order_tracking_screen.dart';
import 'package:quick_basket/features/admin/screens/admin_categories_screen.dart';
import 'package:quick_basket/features/admin/screens/admin_dashboard_screen.dart';
import 'package:quick_basket/services/supabase_service.dart';
import 'package:quick_basket/models/order_model.dart';
import 'package:quick_basket/models/cart_item_model.dart';
import 'package:quick_basket/models/address_model.dart';
import 'package:quick_basket/models/delivery_area_model.dart';
import 'package:quick_basket/shared_widgets/product_card.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void useSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  testWidgets('Mobile storefront smoke test with bottom navigation', (WidgetTester tester) async {
    useSize(tester, const Size(390, 844));

    await tester.pumpWidget(const QuickBasketApp(useGoogleFonts: false));
    await tester.pump();

    // Home list renders with real height
    final listViews = find.byType(ListView);
    expect(listViews, findsWidgets);
    expect(tester.getSize(listViews.first).height, greaterThan(100.0));

    // Header + sections from the approved design (Nizampet 500090 dark store ETA)
    expect(find.text('11 minutes'), findsOneWidget);
    expect(find.text(AppStrings.exploreCategories), findsOneWidget);

    // Scroll to reveal product rails
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.dealsAndDiscounts), findsOneWidget);

    // Profile tab shows the guest login card
    await tester.tap(find.text(AppStrings.navProfile));
    await tester.pumpAndSettle();
    expect(find.text('Login or Sign Up'), findsOneWidget);
    expect(find.text('Login with Mobile Number'), findsOneWidget);

    // Categories tab shows grouped categories
    await tester.tap(find.text(AppStrings.navCategories));
    await tester.pumpAndSettle();
    expect(find.text('All Categories'), findsOneWidget);

    // Cart tab empty state
    await tester.tap(find.text(AppStrings.navCart));
    await tester.pumpAndSettle();
    expect(find.text('Your cart is empty'), findsOneWidget);

    // Orders tab
    await tester.tap(find.text(AppStrings.navOrders));
    await tester.pumpAndSettle();
    expect(find.text('My Orders'), findsOneWidget);

    // Back to Home
    await tester.tap(find.text(AppStrings.navHome));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.exploreCategories), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Desktop storefront uses header navigation and adds to cart', (WidgetTester tester) async {
    useSize(tester, const Size(1440, 900));

    await tester.pumpWidget(const QuickBasketApp(useGoogleFonts: false));
    await tester.pump();

    // Desktop header (no bottom navigation)
    expect(find.text('Delivery in 11 minutes'), findsWidgets);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('My cart'), findsOneWidget);

    // Add the first product to the cart; header cart button updates
    await tester.ensureVisible(find.text('ADD').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ADD').first);
    await tester.pumpAndSettle();
    expect(find.text('1 item'), findsOneWidget);

    // Cart button opens the desktop checkout
    await tester.tap(find.text('1 item'));
    await tester.pumpAndSettle();
    expect(find.text('Checkout'), findsOneWidget);
    expect(find.text('Delivery address'), findsOneWidget);
    expect(find.text('Payment method'), findsOneWidget);

    // Account opens profile
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Login or Sign Up'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Admin Login Screen smoke test', (WidgetTester tester) async {
    useSize(tester, const Size(1200, 800));

    await tester.pumpWidget(const QuickBasketApp(useGoogleFonts: false));
    await tester.pump();

    final BuildContext context = tester.element(find.byType(HomeScreen));
    Navigator.pushNamed(context, '/admin');
    await tester.pumpAndSettle();

    expect(find.text('STORE STAFF PORTAL'), findsOneWidget);
    expect(find.text('Sign in to dashboard'), findsOneWidget);
    expect(find.text('Use demo manager account'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Real-time order status tracking reacts to SupabaseService update', (WidgetTester tester) async {
    useSize(tester, const Size(390, 844));

    // 1. Ensure sample orders are seeded
    await SupabaseService().getUserOrders('test-user');
    await SupabaseService().updateOrderStatus('#QB-93108', OrderStatus.outForDelivery);
    final activeOrder = SupabaseService().getOrderById('#QB-93108');
    expect(activeOrder, isNotNull);

    // 2. Pump OrderTrackingScreen
    await tester.pumpWidget(MaterialApp(home: OrderTrackingScreen(order: activeOrder!)));
    await tester.pump();

    // Verify initial status
    expect(find.text('Order #QB-93108'), findsOneWidget);
    expect(find.text('Delivery OTP'), findsOneWidget);

    // 3. Simulate Store Manager updating order status to Delivered
    await SupabaseService().updateOrderStatus('#QB-93108', OrderStatus.delivered);
    await tester.pump(const Duration(milliseconds: 200));

    // 4. Tracking screen reacts: delivered headline, OTP card removed
    expect(find.text('Delivered — enjoy!'), findsOneWidget);
    expect(find.text('Delivery OTP'), findsNothing);

    // 5. Clean up timers by unmounting widget
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Customer Orders tab updates in real-time when admin marks order delivered', (WidgetTester tester) async {
    useSize(tester, const Size(390, 844));

    // 1. Seed orders so #QB-93108 is outForDelivery
    await SupabaseService().updateOrderStatus('#QB-93108', OrderStatus.outForDelivery);

    await tester.pumpWidget(const QuickBasketApp(useGoogleFonts: false));
    await tester.pump();

    // 2. Tap Orders tab
    await tester.tap(find.text(AppStrings.navOrders));
    await tester.pumpAndSettle();

    // 3. Active order shows a Track order action
    expect(find.text('Track order'), findsOneWidget);

    // 4. Admin marks order delivered (across tabs / backend)
    await SupabaseService().updateOrderStatus('#QB-93108', OrderStatus.delivered);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // 5. Track action disappears; card shows Delivered + Reorder
    expect(find.text('Track order'), findsNothing);
    expect(find.text('Delivered'), findsWidgets);
    expect(find.text('Reorder'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Admin Live Orders board gives clear feedback and supports undo', (WidgetTester tester) async {
    useSize(tester, const Size(1440, 1000));

    await SupabaseService().getAllStoreOrders();
    await SupabaseService().updateOrderStatus('#QB-93108', OrderStatus.placed);

    await tester.pumpWidget(MaterialApp(
      home: AdminDashboardScreen(
        managerData: const {'name': 'Store Manager', 'email': 'manager@quickbasket.com'},
      ),
    ));
    await tester.pumpAndSettle();

    // Open the Live Orders board from the sidebar
    await tester.tap(find.text('Live Orders').first);
    await tester.pumpAndSettle();
    expect(find.text('New orders'), findsOneWidget);

    // Accept the new order
    await tester.tap(find.text('Accept order').first);
    await tester.pumpAndSettle();

    // Clear feedback: banner, highlighted card, next-step hint
    expect(find.text('Order #QB-93108 accepted'), findsOneWidget);
    expect(find.text('Just accepted'), findsOneWidget);
    expect(SupabaseService().getOrderById('#QB-93108')!.status, OrderStatus.confirmed);

    // Undo returns the order to New orders
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(SupabaseService().getOrderById('#QB-93108')!.status, OrderStatus.placed);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Dynamic Category & Subcategory CRUD and Admin Categories Screen test', (WidgetTester tester) async {
    useSize(tester, const Size(1200, 800));

    // 1. Create a dynamic category via SupabaseService
    final newCategory = await SupabaseService().createCategory(
      name: 'Gourmet Organic',
      slug: 'gourmet-organic',
      iconName: 'eco',
      colorHex: '#E8F5E9',
      displayOrder: 99,
      isActive: true,
    );
    expect(newCategory.name, 'Gourmet Organic');

    // 2. Fetch categories and verify the new category is present
    final categories = await SupabaseService().getCategories();
    expect(categories.any((c) => c.name == 'Gourmet Organic'), isTrue);

    // 3. Create a dynamic subcategory assigned under Gourmet Organic
    final newSubcategory = await SupabaseService().createSubcategory(
      categoryId: newCategory.id,
      name: 'Organic Honey',
      slug: 'organic-honey',
      displayOrder: 1,
      isActive: true,
    );
    expect(newSubcategory.name, 'Organic Honey');
    expect(newSubcategory.categoryId, newCategory.id);

    // 4. Verify subcategories for this category
    final subs = await SupabaseService().getSubcategories(categoryId: newCategory.id);
    expect(subs.any((s) => s.name == 'Organic Honey'), isTrue);

    // 5. Toggle subcategory status to inactive
    await SupabaseService().toggleSubcategoryStatus(newSubcategory.id, false);
    final activeSubs = await SupabaseService().getSubcategories(categoryId: newCategory.id, includeInactive: false);
    expect(activeSubs.any((s) => s.name == 'Organic Honey'), isFalse);

    // 6. Toggle category status to inactive
    await SupabaseService().toggleCategoryStatus(newCategory.id, false);
    final activeCategories = await SupabaseService().getCategories();
    expect(activeCategories.any((c) => c.name == 'Gourmet Organic'), isFalse);

    // 7. Pump AdminCategoriesScreen and verify the master-detail UI renders
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AdminCategoriesScreen(embedded: true))));
    await tester.pumpAndSettle();

    expect(find.text('Categories & Subcategories'), findsOneWidget);
    expect(find.text('Add Category'), findsOneWidget);
    expect(find.text('Add Subcategory'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Live stock capping and out-of-stock badges enforce limits correctly', (WidgetTester tester) async {
    useSize(tester, const Size(1440, 900));

    await tester.pumpWidget(const QuickBasketApp(useGoogleFonts: false));
    await tester.pump();

    // Verify out-of-stock indicators exist for prod-4 (Fresh Hydroponic Spinach, stock 0)
    expect(find.text('OUT OF STOCK'), findsWidgets);
    expect(find.text('Sold out'), findsWidgets);

    // Verify low-stock indicator exists for prod-7 (Cold Pressed Tender Coconut Water, stock 2)
    expect(find.text('Only 2 left'), findsWidgets);

    // Add low-stock product (prod-7) to cart
    final coconutAddFinder = find.ancestor(
      of: find.text('Cold Pressed Tender Coconut Water'),
      matching: find.byType(ProductCard),
    );
    expect(coconutAddFinder, findsWidgets);

    // Tap ADD on Cold Pressed Tender Coconut Water
    final addBtn = find.descendant(of: coconutAddFinder.first, matching: find.text('ADD'));
    await tester.ensureVisible(addBtn);
    await tester.pumpAndSettle();
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    // Now quantity is 1. Tap '+' to reach max stock (2)
    final plusBtn = find.descendant(of: coconutAddFinder.first, matching: find.byIcon(Icons.add_rounded));
    await tester.tap(plusBtn);
    await tester.pumpAndSettle();

    // Quantity should be 2
    expect(find.descendant(of: coconutAddFinder.first, matching: find.text('2')), findsOneWidget);

    // Tap '+' again when max stock (2) is reached
    await tester.tap(plusBtn);
    await tester.pumpAndSettle();

    // Quantity must stay 2 (capped) and notification must be shown
    expect(find.descendant(of: coconutAddFinder.first, matching: find.text('2')), findsOneWidget);
    expect(find.text('Only 2 units available for Cold Pressed Tender Coconut Water'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Atomic stock decrement on order placement and auto-restoral on 60s cancellation', (WidgetTester tester) async {
    useSize(tester, const Size(1440, 900));

    // Reset prod-7 stock to 2
    await SupabaseService().updateProductStock('prod-7', 'var-7-1', 2);
    final initialProducts = await SupabaseService().getProducts();
    final initialCoconut = initialProducts.firstWhere((p) => p.id == 'prod-7');
    expect(initialCoconut.defaultVariant.stockQuantity, 2);
    expect(initialCoconut.defaultVariant.isOutOfStock, isFalse);

    // Place an order for 2 units of prod-7
    final cartItem = CartItemModel(
      product: initialCoconut,
      variant: initialCoconut.defaultVariant,
      quantity: 2,
    );

    final order = await SupabaseService().createOrder(
      userId: 'test-user-inventory',
      address: AddressModel(
        id: 'addr-inv-1',
        userId: 'test-user-inventory',
        type: 'Home',
        flatHouseNumber: '101',
        areaStreet: 'MG Road',
        city: 'Bengaluru',
        pincode: '560001',
      ),
      items: [cartItem],
      itemTotal: 98.0,
      deliveryFee: 0.0,
      packagingFee: 5.0,
      tipAmount: 0.0,
      couponDiscount: 0.0,
      grandTotal: 103.0,
      paymentMethod: 'upi',
    );

    expect(order, isNotNull);

    // 1. Verify stock decremented to 0
    final productsAfterOrder = await SupabaseService().getProducts();
    final orderedCoconut = productsAfterOrder.firstWhere((p) => p.id == 'prod-7');
    expect(orderedCoconut.defaultVariant.stockQuantity, 0);
    expect(orderedCoconut.defaultVariant.isOutOfStock, isTrue);

    // 2. Ordering an out-of-stock product should be blocked
    expect(
      () => SupabaseService().createOrder(
        userId: 'test-user-inventory',
        address: AddressModel(
          id: 'addr-inv-1',
          userId: 'test-user-inventory',
          type: 'Home',
          flatHouseNumber: '101',
          areaStreet: 'MG Road',
          city: 'Bengaluru',
          pincode: '560001',
        ),
        items: [cartItem],
        itemTotal: 98.0,
        deliveryFee: 0.0,
        packagingFee: 5.0,
        tipAmount: 0.0,
        couponDiscount: 0.0,
        grandTotal: 103.0,
        paymentMethod: 'upi',
      ),
      throwsA(isA<Exception>()),
    );

    // 3. Test OrderTrackingScreen cancellation UI
    await tester.pumpWidget(MaterialApp(home: OrderTrackingScreen(order: order!)));
    await tester.pumpAndSettle();

    // Verify cancellation button is present in the 60s window
    expect(find.text('Cancel'), findsWidgets);
    await tester.tap(find.text('Cancel').first);
    await tester.pumpAndSettle();

    // Confirm cancel in dialog
    expect(find.text('Cancel Order?'), findsOneWidget);
    await tester.tap(find.text('Yes, cancel order'));
    await tester.pumpAndSettle();

    // 4. Verify order is cancelled and stock is automatically restored to 2
    expect(find.text('Order was cancelled. All items were returned to store stock.'), findsWidgets);

    final productsAfterCancel = await SupabaseService().getProducts();
    final restoredCoconut = productsAfterCancel.firstWhere((p) => p.id == 'prod-7');
    expect(restoredCoconut.defaultVariant.stockQuantity, 2);
    expect(restoredCoconut.defaultVariant.isOutOfStock, isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  test('Geofencing Engine: Dark store 500090 hub and surrounding Telangana zones', () async {
    // 1. Dark store location is centered on Nizampet, Telangana 500090
    expect(DarkStoreConfig.hubPincode, '500090');
    expect(DarkStoreConfig.hubCity, 'Hyderabad');
    expect(DarkStoreConfig.hubState, 'Telangana');
    expect(DarkStoreConfig.maxDeliveryRadiusKm, 5.5);

    // 2. Primary hub pincode 500090 is deliverable with 11 mins ETA
    expect(DarkStoreConfig.isPincodeDeliverable('500090'), isTrue);
    expect(DarkStoreConfig.getEstimatedMinutesForPincode('500090'), 11);

    // 3. Surrounding Telangana pincodes are deliverable
    final surrounding = ['500072', '500085', '500049', '500055'];
    for (final pin in surrounding) {
      expect(DarkStoreConfig.isPincodeDeliverable(pin), isTrue, reason: 'Pincode $pin should be deliverable');
    }

    // 4. Distant or out-of-zone pincodes are strictly unserviceable
    final unserviceable = ['500034', '500001', '560001', '110001'];
    for (final pin in unserviceable) {
      expect(DarkStoreConfig.isPincodeDeliverable(pin), isFalse, reason: 'Pincode $pin should be outside delivery zone');
    }

    // 5. Haversine distance verification: 500090 coordinates within < 0.1km, 500034 Banjara Hills > 10km
    final distHub = DarkStoreConfig.calculateDistanceKm(
      DarkStoreConfig.hubLatitude,
      DarkStoreConfig.hubLongitude,
      17.5186,
      78.3845,
    );
    expect(distHub, lessThan(0.1));

    final distBanjara = DarkStoreConfig.calculateDistanceKm(
      DarkStoreConfig.hubLatitude,
      DarkStoreConfig.hubLongitude,
      17.4156,
      78.4350,
    );
    expect(distBanjara, greaterThan(10.0));
  });

  test('SupabaseService: checkServiceability for 500090 vs unserviceable pincodes', () async {
    final service = SupabaseService();

    // 1. Serviceable check for Nizampet 500090
    final res90 = await service.checkServiceability(pincode: '500090');
    expect(res90.isServiceable, isTrue);
    expect(res90.estimatedMinutes, 11);
    expect(res90.deliveryFee, 25.0);
    expect(res90.minOrderValue, 99.0);
    expect(res90.freeDeliveryAbove, 199.0);
    expect(res90.statusHeadline, contains(RegExp(r'11 mins', caseSensitive: false)));

    // 2. Unserviceable check for Banjara Hills 500034
    final res34 = await service.checkServiceability(pincode: '500034');
    expect(res34.isServiceable, isFalse);
    expect(res34.statusHeadline, 'Location Not Serviceable');
    expect(res34.statusMessage, contains('500034 is outside'));

    // 3. Admin Delivery Areas management
    final areas = await service.getDeliveryAreas(onlyActive: false);
    expect(areas.length, greaterThanOrEqualTo(5));
    expect(areas.any((a) => a.pincode == '500090'), isTrue);

    // Toggle area active status
    final area90 = areas.firstWhere((a) => a.pincode == '500090');
    await service.toggleDeliveryArea(area90.id, false);

    final res90Inactive = await service.checkServiceability(pincode: '500090');
    expect(res90Inactive.isServiceable, isFalse);

    // Restore area active status
    await service.toggleDeliveryArea(area90.id, true);
    final res90Restored = await service.checkServiceability(pincode: '500090');
    expect(res90Restored.isServiceable, isTrue);
  });

  testWidgets('Checkout enforces unserviceable location blocking and dynamic delivery fee', (WidgetTester tester) async {
    useSize(tester, const Size(390, 844));

    await tester.pumpWidget(const QuickBasketApp(useGoogleFonts: false));
    await tester.pump();

    // 1. Scroll down on home to reveal product rails and add to cart
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('ADD'), findsWidgets);
    await tester.tap(find.text('ADD').first);
    await tester.pumpAndSettle();

    // 2. Open Cart tab
    await tester.tap(find.text(AppStrings.navCart));
    await tester.pumpAndSettle();

    // Cart shows serviceable ETA for default Nizampet 500090
    expect(find.textContaining('11 minutes'), findsWidgets);

    // Minimum order value (₹99) is enforced: button shows "Min order ₹99"
    expect(find.textContaining('Min order ₹99'), findsOneWidget);

    // Increase quantity so cart exceeds min order value (₹99)
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    // Now min order threshold is met and "Proceed to pay" is enabled
    expect(find.text('Proceed to pay'), findsOneWidget);
    await tester.tap(find.text('Proceed to pay'));
    await tester.pumpAndSettle();

    expect(find.text('Checkout'), findsOneWidget);

    // Place Order is enabled for serviceable address
    expect(find.textContaining('Place Order'), findsOneWidget);

    // 4. Select unserviceable address (500034 Banjara Hills)
    final unserviceableFinder = find.textContaining('500034');
    expect(unserviceableFinder, findsOneWidget);
    await tester.tap(unserviceableFinder);
    await tester.pumpAndSettle();

    // Verify unserviceable badge is displayed
    expect(find.text('OUT OF ZONE'), findsWidgets);

    // Verify checkout button is disabled with Unserviceable Location notice
    expect(find.text('Unserviceable Location · Change Address'), findsOneWidget);

    // 5. Switching back to 500090 re-enables checkout
    final serviceableFinder = find.textContaining('500090');
    expect(serviceableFinder, findsWidgets);
    await tester.tap(serviceableFinder.first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Place Order'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
