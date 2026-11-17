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

    // Header + sections from the approved design
    expect(find.text('12 minutes'), findsOneWidget);
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
    expect(find.text('Delivery in 12 minutes'), findsWidgets);
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
}
