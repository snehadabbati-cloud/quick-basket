import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_basket/main.dart';
import 'package:quick_basket/core/constants/app_strings.dart';
import 'package:quick_basket/shared_widgets/responsive_wrapper.dart';
import 'package:quick_basket/features/home/screens/home_screen.dart';
import 'package:quick_basket/features/order/screens/order_tracking_screen.dart';
import 'package:quick_basket/services/supabase_service.dart';
import 'package:quick_basket/models/order_model.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('Quick Basket full smoke test with non-zero height', (WidgetTester tester) async {
    // Set a realistic screen size (desktop web: 1200x800)
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const QuickBasketApp());
    await tester.pump();

    // Verify non-zero size for ListView
    final listViews = find.byType(ListView);
    expect(listViews, findsWidgets);
    final homeListSize = tester.getSize(listViews.first);
    debugPrint('Verified Home ListView size: $homeListSize');
    expect(homeListSize.height, greaterThan(100.0));

    // Verify exploreCategories is visible
    expect(find.text(AppStrings.exploreCategories), findsOneWidget);

    // Drag up to reveal Popular Products in the ListView
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.popularProducts), findsOneWidget);

    // Verify tapping Profile tab in bottom navigation switches tab to Profile
    final profileTabFinder = find.text(AppStrings.navProfile);
    expect(profileTabFinder, findsOneWidget);
    await tester.tap(profileTabFinder);
    await tester.pumpAndSettle();

    // Profile tab should show login / sign up card
    expect(find.text('Login or Sign Up'), findsOneWidget);
    expect(find.text('Login with Mobile Number'), findsOneWidget);

    // Tap back to Home tab
    final homeTabFinder = find.text(AppStrings.navHome);
    expect(homeTabFinder, findsOneWidget);
    await tester.tap(homeTabFinder);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.exploreCategories), findsOneWidget);

    // Tap Orders tab
    final ordersTabFinder = find.text(AppStrings.navOrders);
    expect(ordersTabFinder, findsOneWidget);
    await tester.tap(ordersTabFinder);
    await tester.pumpAndSettle();

    // Verify Orders tab rendered
    expect(find.byType(ListView), findsWidgets);
  });

  testWidgets('Admin Login Screen smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const QuickBasketApp());
    await tester.pumpAndSettle();

    // Navigate to /admin
    final BuildContext context = tester.element(find.byType(HomeScreen));
    Navigator.pushNamed(context, '/admin');
    await tester.pumpAndSettle();

    expect(find.text('Quick Basket Operations'), findsOneWidget);
    expect(find.text('Dark Store Manager & Staff Portal'), findsOneWidget);
    expect(find.text('1-Tap Demo Manager Login'), findsOneWidget);
  });

  testWidgets('Real-time order status tracking reacts to SupabaseService update', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    // 1. Ensure sample orders are seeded
    await SupabaseService().getUserOrders('test-user');
    final activeOrder = SupabaseService().getOrderById('#QB-93108');
    expect(activeOrder, isNotNull);

    // 2. Pump OrderTrackingScreen
    await tester.pumpWidget(
      MaterialApp(
        home: OrderTrackingScreen(order: activeOrder!),
      ),
    );
    await tester.pump();

    // Verify initial status
    expect(find.text('Order #QB-93108'), findsOneWidget);
    expect(find.text('Delivery Verification OTP'), findsOneWidget);

    // 3. Simulate Store Manager updating order status to Delivered
    await SupabaseService().updateOrderStatus('#QB-93108', OrderStatus.delivered);
    await tester.pump(const Duration(milliseconds: 200));

    // 4. Verify tracking screen reactively transitioned to Delivered celebration state
    expect(find.text('Order Delivered!'), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text('Order delivered! Enjoy your fresh groceries 🎉'), findsOneWidget);

    // 5. Clean up timers by unmounting widget
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Customer Orders tab updates in real-time when admin marks order delivered', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    // 1. Seed orders so #QB-93108 is outForDelivery
    await SupabaseService().updateOrderStatus('#QB-93108', OrderStatus.outForDelivery);

    await tester.pumpWidget(const QuickBasketApp());
    await tester.pumpAndSettle();

    // 2. Tap Orders tab
    final ordersTabFinder = find.text(AppStrings.navOrders);
    await tester.tap(ordersTabFinder);
    await tester.pumpAndSettle();

    // 3. Verify Live Order banner is initially visible
    expect(find.text('Live Order in Progress!'), findsOneWidget);
    expect(find.text('Track Live'), findsOneWidget);

    // 4. Admin marks order delivered (across tabs / backend)
    await SupabaseService().updateOrderStatus('#QB-93108', OrderStatus.delivered);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // 5. Verify Live Order banner has disappeared completely (Blinkit flow)
    expect(find.text('Live Order in Progress!'), findsNothing);
    expect(find.text('Track Live'), findsNothing);

    // 6. Verify order card displays Delivered status
    expect(find.text('Delivered'), findsWidgets);

    // 7. Clean up
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
