import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_basket/main.dart';
import 'package:quick_basket/core/constants/app_strings.dart';
import 'package:quick_basket/features/home/screens/home_screen.dart';
import 'package:quick_basket/features/order/screens/order_tracking_screen.dart';
import 'package:quick_basket/features/admin/pages/admin_overview_page.dart';
import 'package:quick_basket/features/admin/screens/admin_categories_screen.dart';
import 'package:quick_basket/features/admin/screens/admin_dashboard_screen.dart';
import 'package:quick_basket/services/supabase_service.dart';
import 'package:quick_basket/models/order_model.dart';
import 'package:quick_basket/models/cart_item_model.dart';
import 'package:quick_basket/models/address_model.dart';
import 'package:quick_basket/models/delivery_area_model.dart';
import 'package:quick_basket/models/delivery_partner_model.dart';
import 'package:quick_basket/core/config/delivery_config.dart';
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
    expect(find.textContaining('You cancelled this order'), findsWidgets);
    expect(find.text('This order was cancelled by you'), findsOneWidget);

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

  testWidgets('Order Cancellation: Customer cancellation vs Store cancellation & Admin table visibility', (WidgetTester tester) async {
    useSize(tester, const Size(1280, 800));

    final customerCancelledOrder = OrderModel(
      id: 'test-cancel-customer',
      orderNumber: '#QB-771122',
      userId: 'test-user-1',
      items: [],
      itemTotal: 150.0,
      deliveryFee: 0.0,
      packagingFee: 5.0,
      grandTotal: 155.0,
      status: OrderStatus.cancelled,
      cancellationReason: 'Cancelled by customer',
      paymentMethod: 'upi',
      createdAt: DateTime.now(),
    );

    final storeCancelledOrder = OrderModel(
      id: 'test-cancel-store',
      orderNumber: '#QB-883344',
      userId: 'test-user-2',
      items: [],
      itemTotal: 220.0,
      deliveryFee: 0.0,
      packagingFee: 5.0,
      grandTotal: 225.0,
      status: OrderStatus.cancelled,
      cancellationReason: 'Cancelled by store',
      paymentMethod: 'upi',
      createdAt: DateTime.now(),
    );

    // 1. Customer cancellation screen check
    await tester.pumpWidget(MaterialApp(home: OrderTrackingScreen(order: customerCancelledOrder)));
    await tester.pumpAndSettle();

    expect(find.text('This order was cancelled by you'), findsOneWidget);
    expect(find.textContaining('You cancelled this order'), findsWidgets);
    expect(find.textContaining('This order was cancelled by the store'), findsNothing);

    // 2. Store cancellation screen check
    await tester.pumpWidget(MaterialApp(home: OrderTrackingScreen(order: storeCancelledOrder)));
    await tester.pumpAndSettle();

    expect(find.text('This order was cancelled by the store'), findsOneWidget);
    expect(find.textContaining('Order was cancelled by store'), findsWidgets);

    // 3. Admin Overview Page: cancelled orders are visible and restocked badge is rendered
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminOverviewPage(
            orders: [customerCancelledOrder, storeCancelledOrder],
            customerName: (o) => 'Sneha',
            onAdvance: (_) async {},
            onOpenSection: (_) {},
            onRestock: (_, __) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify orders are present in overview table
    expect(find.text('#QB-771122'), findsOneWidget);
    expect(find.text('#QB-883344'), findsOneWidget);
    expect(find.text('Cancelled (Customer)'), findsOneWidget);
    expect(find.text('Cancelled (Store)'), findsOneWidget);
    expect(find.text('Restocked'), findsWidgets);

    // Tap 'Cancelled' filter segment
    expect(find.text('Cancelled'), findsOneWidget);
    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();

    expect(find.text('#QB-771122'), findsOneWidget);
    expect(find.text('#QB-883344'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('COD Order Cancellation: Displays "No payment was collected for this order" without refund mentions', (WidgetTester tester) async {
    useSize(tester, const Size(400, 850));

    final codCancelledOrder = OrderModel(
      id: 'test-cod-cancel',
      orderNumber: '#QB-040581',
      userId: 'test-user-cod',
      items: [],
      itemTotal: 220.0,
      grandTotal: 220.0,
      paymentMethod: 'cod',
      paymentStatus: 'pending',
      status: OrderStatus.cancelled,
      cancelledBy: 'customer',
      cancellationReason: 'Cancelled by customer',
      refundStatus: 'none',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(MaterialApp(home: OrderTrackingScreen(order: codCancelledOrder)));
    await tester.pumpAndSettle();

    // Verify "No payment was collected for this order." is displayed in both banner and status
    expect(find.textContaining('No payment was collected for this order.'), findsWidgets);

    // Verify NO refund is mentioned
    expect(find.textContaining('Full refund of'), findsNothing);
    expect(find.textContaining('A full refund'), findsNothing);
    expect(find.textContaining('refund has been'), findsNothing);
    expect(find.textContaining('refund will be'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Online Payment Cancellation: Displays exact status ("initiated", "processed", "pending")', (WidgetTester tester) async {
    useSize(tester, const Size(400, 850));

    // 1. Initiated
    final onlineInitiatedOrder = OrderModel(
      id: 'test-online-initiated',
      orderNumber: '#QB-112233',
      userId: 'test-user-online',
      items: [],
      itemTotal: 350.0,
      grandTotal: 350.0,
      paymentMethod: 'upi',
      paymentStatus: 'refunded',
      status: OrderStatus.cancelled,
      cancelledBy: 'customer',
      cancellationReason: 'Cancelled by customer',
      refundStatus: 'initiated',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(MaterialApp(home: OrderTrackingScreen(order: onlineInitiatedOrder)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your refund has been initiated.'), findsWidgets);

    // 2. Processed
    final onlineProcessedOrder = onlineInitiatedOrder.copyWith(id: 'test-online-processed', refundStatus: 'processed');
    await tester.pumpWidget(MaterialApp(home: OrderTrackingScreen(key: const ValueKey('processed'), order: onlineProcessedOrder)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your refund has been successfully processed.'), findsWidgets);

    // 3. Pending
    final onlinePendingOrder = onlineInitiatedOrder.copyWith(id: 'test-online-pending', refundStatus: 'pending');
    await tester.pumpWidget(MaterialApp(home: OrderTrackingScreen(key: const ValueKey('pending'), order: onlinePendingOrder)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your refund is being processed.'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  test('OrderModel serialization maintains all cancellation and refund fields for Supabase', () {
    final order = OrderModel(
      id: 'db-order-uuid-1',
      orderNumber: '#QB-998877',
      userId: 'user-uuid-1',
      storeId: '11111111-1111-1111-1111-111111111111',
      items: [],
      itemTotal: 100.0,
      grandTotal: 105.0,
      paymentMethod: 'cod',
      paymentStatus: 'pending',
      status: OrderStatus.cancelled,
      cancelledBy: 'customer',
      cancellationReason: 'Accidental order',
      cancelledAt: DateTime(2026, 11, 19, 10, 0, 0),
      refundStatus: 'none',
    );

    final json = order.toJson();
    expect(json['cancelled_by'], 'customer');
    expect(json['cancellation_reason'], 'Accidental order');
    expect(json['cancelled_at'], isNotNull);
    expect(json['refund_status'], 'none');
    expect(json['order_status'], 'cancelled');

    final parsed = OrderModel.fromJson(json);
    expect(parsed.cancelledBy, 'customer');
    expect(parsed.cancellationReason, 'Accidental order');
    expect(parsed.refundStatus, 'none');
    expect(parsed.status, OrderStatus.cancelled);
    expect(parsed.isCod, isTrue);
    expect(parsed.refundStatusMessage, 'No payment was collected for this order.');

    // Status enum aliases check
    expect(OrderStatusExtension.fromString('pending'), OrderStatus.placed);
    expect(OrderStatusExtension.fromString('accepted'), OrderStatus.confirmed);
    expect(OrderStatusExtension.fromString('preparing'), OrderStatus.packing);
    expect(OrderStatusExtension.fromString('partner_assigned'), OrderStatus.partnerAssigned);
    expect(OrderStatusExtension.fromString('out_for_delivery'), OrderStatus.outForDelivery);
    expect(OrderStatusExtension.fromString('delivered'), OrderStatus.delivered);
    expect(OrderStatusExtension.fromString('cancelled'), OrderStatus.cancelled);
  });

  test('DeliveryPartnerModel defaults to offline and serializes cleanly', () {
    final newRider = DeliveryPartnerModel(
      id: 'rider-001',
      name: 'Ramesh Kumar',
      phone: '+919876543210',
      vehicleNumber: 'TS 09 AB 1234',
    );

    // Rule: New riders must default to offline
    expect(newRider.status, DeliveryPartnerStatus.offline);
    expect(newRider.isOnline, isFalse);
    expect(newRider.isAvailable, isFalse);

    final json = newRider.toJson();
    expect(json['status'], 'offline');
    expect(json['name'], 'Ramesh Kumar');

    final parsed = DeliveryPartnerModel.fromJson(json);
    expect(parsed.status, DeliveryPartnerStatus.offline);
    expect(parsed.vehicleNumber, 'TS 09 AB 1234');
  });

  test('OrderModel toRiderView strips plain-text delivery OTP for security', () {
    final customerOrder = OrderModel(
      id: 'order-sec-1',
      orderNumber: '#QB-101010',
      userId: 'customer-1',
      items: [],
      itemTotal: 150.0,
      grandTotal: 150.0,
      deliveryOtp: '4821',
      riderId: 'rider-001',
      riderName: 'Ramesh Kumar',
      status: OrderStatus.outForDelivery,
    );

    expect(customerOrder.deliveryOtp, '4821');

    final riderOrderView = customerOrder.toRiderView();
    // Security check: Rider view MUST NOT contain plain text delivery OTP
    expect(riderOrderView.deliveryOtp, isEmpty);
    expect(riderOrderView.riderId, 'rider-001');
    expect(riderOrderView.riderName, 'Ramesh Kumar');
  });

  test('OrderModel serializes and deserializes all rider fields for Supabase', () {
    final assignedTime = DateTime(2026, 11, 20, 10, 0, 0);
    final pickedTime = DateTime(2026, 11, 20, 10, 15, 0);
    final deliveredTime = DateTime(2026, 11, 20, 10, 30, 0);
    final expiryTime = DateTime(2026, 11, 20, 12, 0, 0);

    final order = OrderModel(
      id: 'order-rider-fields',
      orderNumber: '#QB-223344',
      userId: 'cust-2',
      items: [],
      itemTotal: 250.0,
      grandTotal: 250.0,
      status: OrderStatus.partnerAssigned,
      riderId: 'rider-001',
      riderName: 'Ramesh Kumar',
      riderPhone: '+919876543210',
      riderVehicleNumber: 'TS 09 AB 1234',
      deliveryStage: 'assigned',
      assignedAt: assignedTime,
      pickedUpAt: pickedTime,
      deliveredAt: deliveredTime,
      otpAttempts: 1,
      otpExpiresAt: expiryTime,
    );

    final json = order.toJson();
    expect(json['rider_id'], 'rider-001');
    expect(json['rider_name'], 'Ramesh Kumar');
    expect(json['rider_phone'], '+919876543210');
    expect(json['rider_vehicle'], 'TS 09 AB 1234');
    expect(json['delivery_stage'], 'assigned');
    expect(json['order_status'], 'partner_assigned');
    expect(json['otp_attempts'], 1);

    final parsed = OrderModel.fromJson(json);
    expect(parsed.riderId, 'rider-001');
    expect(parsed.riderName, 'Ramesh Kumar');
    expect(parsed.riderPhone, '+919876543210');
    expect(parsed.riderVehicleNumber, 'TS 09 AB 1234');
    expect(parsed.deliveryStage, 'assigned');
    expect(parsed.status, OrderStatus.partnerAssigned);
    expect(parsed.otpAttempts, 1);
  });

  test('DeliveryConfig centralizes constants and thresholds', () {
    expect(DeliveryConfig.maxOtpAttempts, 3);
    expect(DeliveryConfig.defaultPerDeliveryEarning, 40.0);
    expect(DeliveryConfig.defaultStorePincode, '500090');
    expect(DeliveryConfig.defaultStoreName, 'Nizampet Dark Store');
  });

  test('SupabaseService verifyDoorstepOtp enforces attempt limit, lockout, and atomic delivery completion', () async {
    final service = SupabaseService();

    // Setup an order with known OTP
    final testOrder = OrderModel(
      id: 'otp-test-order-1',
      orderNumber: '#QB-778899',
      userId: 'cust-otp-test',
      items: [],
      itemTotal: 300.0,
      grandTotal: 300.0,
      status: OrderStatus.outForDelivery,
      deliveryStage: 'out_for_delivery',
      deliveryOtp: '6543',
      riderId: 'rider-test-01',
      otpAttempts: 0,
      otpExpiresAt: DateTime.now().add(const Duration(hours: 2)),
    );

    // Seed test order into service local cache
    service.seedOrder(testOrder);
    await service.assignRiderToOrder(
      orderId: testOrder.id,
      riderId: 'rider-test-01',
    );

    // 1. Wrong OTP Attempt 1
    var result = await service.verifyDoorstepOtp(
      orderId: testOrder.id,
      enteredOtp: '0000',
      riderId: 'rider-test-01',
    );
    expect(result['success'], isFalse);
    expect(result['remaining_attempts'], 2);
    expect(result['locked'], isFalse);

    // 2. Wrong OTP Attempt 2
    result = await service.verifyDoorstepOtp(
      orderId: testOrder.id,
      enteredOtp: '1111',
      riderId: 'rider-test-01',
    );
    expect(result['success'], isFalse);
    expect(result['remaining_attempts'], 1);
    expect(result['locked'], isFalse);

    // 3. Wrong OTP Attempt 3 -> Lockout
    result = await service.verifyDoorstepOtp(
      orderId: testOrder.id,
      enteredOtp: '2222',
      riderId: 'rider-test-01',
    );
    expect(result['success'], isFalse);
    expect(result['remaining_attempts'], 0);
    expect(result['locked'], isTrue);

    // 4. Any further attempt is rejected even if correct OTP because of lockout
    result = await service.verifyDoorstepOtp(
      orderId: testOrder.id,
      enteredOtp: '6543',
      riderId: 'rider-test-01',
    );
    expect(result['success'], isFalse);
    expect(result['locked'], isTrue);

    // 5. Fresh order with correct OTP succeeds and transitions to delivered
    final freshOrder = testOrder.copyWith(id: 'otp-success-order', otpAttempts: 0);
    service.seedOrder(freshOrder);
    result = await service.verifyDoorstepOtp(
      orderId: freshOrder.id,
      enteredOtp: '6543',
      riderId: 'rider-test-01',
    );
    expect(result['success'], isTrue);
    final deliveredOrder = service.getOrderById(freshOrder.id);
    expect(deliveredOrder?.status, OrderStatus.delivered);
    expect(deliveredOrder?.deliveredAt, isNotNull);
  });
}
