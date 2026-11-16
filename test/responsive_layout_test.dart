import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_basket/main.dart';
import 'package:quick_basket/core/constants/app_strings.dart';
import 'package:quick_basket/core/theme/app_theme.dart';
import 'package:quick_basket/features/admin/screens/admin_dashboard_screen.dart';
import 'package:quick_basket/features/admin/screens/admin_login_screen.dart';
import 'package:quick_basket/features/admin/widgets/admin_sidebar.dart';
import 'package:quick_basket/features/auth/screens/phone_login_screen.dart';
import 'package:quick_basket/services/supabase_service.dart';

/// Renders every redesigned screen at phone, tablet and desktop sizes.
/// Any layout overflow is reported as a test failure by the framework.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const sizes = [Size(390, 844), Size(820, 1180), Size(1280, 800), Size(1440, 900)];

  void useSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  for (final size in sizes) {
    testWidgets('Admin pages render without overflow at ${size.width.toInt()}px', (tester) async {
      useSize(tester, size);
      await SupabaseService().getAllStoreOrders();
      for (final section in AdminSection.values) {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(googleFonts: false),
          home: AdminDashboardScreen(
            key: ValueKey(section),
            managerData: const {'name': 'Store Manager', 'email': 'manager@quickbasket.com'},
            initialSection: section,
          ),
        ));
        await tester.pumpAndSettle();
        // Any overflow here fails the test with the widget location.
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('Admin login renders at ${size.width.toInt()}px', (tester) async {
      useSize(tester, size);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light(googleFonts: false), home: const AdminLoginScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to dashboard'), findsOneWidget);
    });

    testWidgets('Customer login renders at ${size.width.toInt()}px', (tester) async {
      useSize(tester, size);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light(googleFonts: false), home: const PhoneLoginScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Login with Mobile Number'), findsOneWidget);
    });
  }

  for (final size in const [Size(390, 844), Size(820, 1180)]) {
    testWidgets('Mobile storefront tabs and checkout render at ${size.width.toInt()}px', (tester) async {
      useSize(tester, size);
      await tester.pumpWidget(const QuickBasketApp(useGoogleFonts: false));
      await tester.pumpAndSettle();

      // Add an item, then walk every tab
      for (var i = 0; i < 10 && find.text('ADD').hitTestable().evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('ADD').hitTestable().first);
      await tester.pumpAndSettle();

      for (final tab in [AppStrings.navCategories, AppStrings.navOrders, AppStrings.navProfile, AppStrings.navCart]) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
      }

      // Cart → checkout
      expect(find.text('Proceed to pay'), findsOneWidget);
      await tester.tap(find.text('Proceed to pay'));
      await tester.pumpAndSettle();
      expect(find.text('Payment method'), findsOneWidget);

      // Open a category page from Home
      await tester.tap(find.text(AppStrings.navHome).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fruits & Vegetables').first);
      await tester.pumpAndSettle();
      expect(find.text('Filters'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  for (final size in const [Size(1100, 800), Size(1440, 900)]) {
    testWidgets('Desktop storefront pages render at ${size.width.toInt()}px', (tester) async {
      useSize(tester, size);
      await tester.pumpWidget(const QuickBasketApp(useGoogleFonts: false));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('ADD').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ADD').first);
      await tester.pumpAndSettle();

      final scaffold = tester.element(find.byType(Scaffold).first);
      // Category page from the header menu
      await tester.tap(find.text('Fruits & Vegetables').first);
      await tester.pumpAndSettle();
      expect(find.text('Go to checkout'), findsOneWidget);
      await tester.tap(find.text('Go to checkout'));
      await tester.pumpAndSettle();
      expect(find.text('Checkout'), findsOneWidget);
      expect(scaffold.mounted, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
