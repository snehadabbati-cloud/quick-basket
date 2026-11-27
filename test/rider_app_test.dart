import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_basket/core/config/delivery_config.dart';
import 'package:quick_basket/core/theme/app_theme.dart';
import 'package:quick_basket/features/rider/controllers/rider_session.dart';
import 'package:quick_basket/features/rider/screens/delivery_flow_screens.dart';
import 'package:quick_basket/features/rider/screens/earnings_screens.dart';
import 'package:quick_basket/features/rider/screens/orders_screens.dart';
import 'package:quick_basket/features/rider/screens/profile_screens.dart';
import 'package:quick_basket/features/rider/screens/rider_login_screen.dart';
import 'package:quick_basket/features/rider/screens/rider_shell.dart';
import 'package:quick_basket/models/address_model.dart';
import 'package:quick_basket/models/cart_item_model.dart';
import 'package:quick_basket/models/delivery_partner_model.dart';
import 'package:quick_basket/models/order_model.dart';
import 'package:quick_basket/services/mock_data_service.dart';
import 'package:quick_basket/services/supabase_service.dart';

/// Delivery Partner app: auth, live sync, delivery actions, earnings, and
/// layout of every screen at phone sizes.
void main() {
  final svc = SupabaseService();
  final session = RiderSession();
  int seq = 0;

  setUpAll(_loadRealFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    session.resetForTest();
    RiderSession.pollInterval = const Duration(seconds: 1);
  });

  Future<DeliveryPartnerModel> newRider({bool online = true}) async {
    seq++;
    final r = await svc.addDeliveryPartner(
      name: 'Test Rider $seq',
      phone: '+91 90000 ${(10000 + seq).toString().padLeft(5, '0')}',
      vehicleNumber: 'TS 08 ZZ ${1000 + seq}',
    );
    if (online) await svc.updateDeliveryPartnerStatus(r.id, DeliveryPartnerStatus.online);
    return (await svc.getDeliveryPartners()).firstWhere((x) => x.id == r.id);
  }

  OrderModel order(String id, {
    String? riderId,
    OrderStatus status = OrderStatus.partnerAssigned,
    String? stage = 'assigned',
    String payment = 'cod',
    double tip = 0,
    DateTime? deliveredAt,
    DateTime? createdAt,
    bool withItems = true,
  }) {
    final products = MockDataService.products;
    return OrderModel(
      id: id,
      orderNumber: '#QB-${id.hashCode.abs() % 900000 + 100000}',
      userId: 'cust-$id',
      address: AddressModel(
        id: 'addr-$id',
        userId: 'cust-$id',
        type: 'Home',
        flatHouseNumber: 'Flat 302, Block B',
        areaStreet: 'Lakshmi Residency, Pragathi Nagar',
        landmark: 'Opp. Vijetha Supermarket',
        latitude: 17.5280,
        longitude: 78.3990,
      ),
      items: withItems
          ? [
              CartItemModel(product: products[0], variant: products[0].variants.first, quantity: 2),
              CartItemModel(product: products[1], variant: products[1].variants.first),
            ]
          : [],
      itemTotal: 460,
      grandTotal: 486,
      tipAmount: tip,
      paymentMethod: payment,
      status: status,
      deliveryOtp: '4321',
      deliveryInstructions: 'Call on arrival, baby sleeping',
      riderId: riderId,
      riderName: riderId != null ? 'Rider' : null,
      deliveryStage: riderId != null ? stage : null,
      assignedAt: riderId != null ? DateTime.now() : null,
      deliveredAt: deliveredAt,
      createdAt: createdAt,
    );
  }

  // ---------------------------------------------------------------------------
  group('Model & sync fixes', () {
    test('copyWith can explicitly clear rider assignment / active order', () {
      final o = order('m1', riderId: 'r1');
      expect(o.copyWith(riderId: null).riderId, 'r1'); // old behaviour kept
      final cleared = o.copyWith(clearRiderAssignment: true);
      expect(cleared.riderId, isNull);
      expect(cleared.deliveryStage, isNull);
      expect(cleared.assignedAt, isNull);

      final r = DeliveryPartnerModel(id: 'x', name: 'x', phone: '1', vehicleNumber: 'v', activeOrderId: 'o1');
      expect(r.copyWith(activeOrderId: null).activeOrderId, 'o1');
      expect(r.copyWith(clearActiveOrder: true).activeOrderId, isNull);
    });

    test('tipAmount survives local persistence (rider tip earnings across tabs)', () {
      final o = order('m2', tip: 25);
      expect(OrderModel.fromJson(o.toJson()).tipAmount, 25);
    });

    test('a decline in another tab clears the stale rider in this tab', () async {
      final rider = await newRider();
      final stale = order('xtab-1', riderId: rider.id);
      svc.seedOrder(stale); // this tab still thinks the rider is assigned

      // Another tab declined: storage holds the order without a rider + tombstone.
      final unassigned = stale.copyWith(status: OrderStatus.packing, clearRiderAssignment: true);
      SharedPreferences.setMockInitialValues({
        'qb_custom_orders_json': jsonEncode([unassigned.toJson()]),
        'qb_rider_unassigned_${stale.id}': DateTime.now().toIso8601String(),
        'qb_status_${stale.id}': 'packing',
      });

      final riderOrders = await svc.getRiderOrders(rider.id);
      expect(riderOrders.where((o) => o.id == stale.id), isEmpty);
      expect(svc.getOrderById(stale.id)?.riderId, isNull);
      expect(svc.getOrderById(stale.id)?.status, OrderStatus.packing);
    });

    test('assigning a built-in demo order reaches the rider app in another tab', () async {
      final rider = await newRider();
      // The demo orders are only auto-seeded into an empty list; ensure #QB-93108 exists.
      if (svc.getOrderById('#QB-93108') == null) {
        svc.seedOrder(order('demo', status: OrderStatus.packing, stage: null)
            .copyWith(id: 'sample-order-active', orderNumber: '#QB-93108'));
      }
      final demo = svc.getOrderById('#QB-93108')!;
      await svc.updateOrderStatus(demo.id, OrderStatus.packing);
      expect(await svc.assignRiderToOrder(orderId: demo.id, riderId: rider.id), isTrue);

      // Rider's tab: its own in-memory copy of the demo order has no rider yet.
      svc.seedOrder(demo.copyWith(status: OrderStatus.packing, clearRiderAssignment: true));
      final list = await svc.getRiderOrders(rider.id);
      expect(list.map((o) => o.id), contains(demo.id));
      expect(list.firstWhere((o) => o.id == demo.id).deliveryStage, 'assigned');
    });

    test('assigning an order that does not exist reports failure (no false "success")', () async {
      final rider = await newRider();
      expect(await svc.assignRiderToOrder(orderId: 'no-such-order', riderId: rider.id), isFalse);
    });

    test('rider status toggled in another tab is picked up (Admin ↔ Rider)', () async {
      final rider = await newRider(online: false);
      final all = (await svc.getDeliveryPartners()).map((r) => r.id == rider.id ? r.copyWith(status: DeliveryPartnerStatus.online) : r);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('qb_delivery_partners_json', jsonEncode(all.map((r) => r.toJson()).toList()));
      await prefs.setString('qb_rider_status_${rider.id}', 'online');

      final fresh = (await svc.getDeliveryPartners()).firstWhere((r) => r.id == rider.id);
      expect(fresh.isOnline, isTrue);
    });

    test('getRiderOrders only returns this rider\'s orders and never the OTP', () async {
      final a = await newRider();
      final b = await newRider();
      svc.seedOrder(order('own-1', riderId: a.id));
      svc.seedOrder(order('other-1', riderId: b.id));
      final list = await svc.getRiderOrders(a.id);
      expect(list.map((o) => o.id), contains('own-1'));
      expect(list.map((o) => o.id), isNot(contains('other-1')));
      expect(list.every((o) => o.deliveryOtp.isEmpty), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('Rider login (phone OTP)', () {
    test('unregistered number is rejected', () async {
      await expectLater(session.requestOtp('9123456780'), throwsA(isA<RiderException>()));
      await expectLater(session.requestOtp('12345'), throwsA(isA<RiderException>()));
    });

    test('debug test rider: no SMS, test code required, session persists & restores', () async {
      final req = await session.requestOtp('98765 43210'); // TestRiderFixtures: Ramesh Kumar
      expect(req.usesTestCode, isTrue);
      expect(req.rider.name, 'Ramesh Kumar');

      await expectLater(session.verifyOtp('000000'), throwsA(isA<RiderException>()));
      final r = await session.verifyOtp(DeliveryConfig.debugTestRiderOtp);
      expect(r.id, 'rider-001');
      expect(session.isLoggedIn, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(RiderSession.sessionKey), 'rider-001');

      session.resetForTest();
      expect(await session.restore(), isTrue);
      expect(session.rider?.id, 'rider-001');

      expect(await session.logout(), isNull);
      expect(session.isLoggedIn, isFalse);
      expect(prefs.getString(RiderSession.sessionKey), isNull);
      expect(await session.restore(), isFalse);
    });

    testWidgets('login screen → OTP screen → home', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const RiderLoginScreen(autoRestore: false)));
      await tester.pump();

      await tester.enterText(find.byKey(const ValueKey('rider_phone_field')), '9111111111');
      await tester.tap(find.text('Send OTP'));
      await _settle(tester);
      expect(find.textContaining('isn\'t registered'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('rider_phone_field')), '9876543210');
      await tester.tap(find.text('Send OTP'));
      await _settle(tester);
      expect(find.text('Hi Ramesh, verify your number'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('rider_otp_field')), DeliveryConfig.debugTestRiderOtp);
      await tester.pump();
      await tester.tap(find.text('Verify & Start Shift'));
      await _settle(tester);
      expect(find.text('Ramesh Kumar'), findsWidgets);
      expect(find.byKey(const ValueKey('rider_duty_switch')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  // ---------------------------------------------------------------------------
  group('Delivery actions & live sync', () {
    testWidgets('admin assignment pops up the request on the open rider app', (tester) async {
      _phone(tester);
      RiderSession.pollInterval = const Duration(milliseconds: 200);
      final rider = await newRider();
      svc.seedOrder(order('live-1', status: OrderStatus.packing, stage: null));
      await session.debugSignIn(rider);

      await tester.pumpWidget(_app(const RiderShell()));
      await _settle(tester);
      expect(find.text('New delivery request'), findsNothing);

      await svc.assignRiderToOrder(orderId: 'live-1', riderId: rider.id); // Admin action
      await _settle(tester);
      expect(find.text('New delivery request'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('unanswered request auto-declines after the response window', (tester) async {
      _phone(tester);
      var now = DateTime.now(); // assignRiderToOrder stamps assignedAt with the real clock
      session.clock = () => now;
      final rider = await newRider();
      svc.seedOrder(order('timeout-1', status: OrderStatus.packing, stage: null));
      await svc.assignRiderToOrder(orderId: 'timeout-1', riderId: rider.id);
      await session.debugSignIn(rider);

      await tester.pumpWidget(_app(const Scaffold(body: Text('home'))));
      tester.state<NavigatorState>(find.byType(Navigator)).push(
        MaterialPageRoute(builder: (_) => const NewDeliveryRequestScreen(orderId: 'timeout-1')),
      );
      await _settle(tester);
      expect(find.text('${DeliveryConfig.requestResponseWindow.inSeconds}s'), findsOneWidget);

      now = now.add(DeliveryConfig.requestResponseWindow + const Duration(seconds: 1));
      await _settle(tester);
      expect(find.text('home'), findsOneWidget);
      expect(svc.getOrderById('timeout-1')?.riderId, isNull);
      expect(svc.getOrderById('timeout-1')?.status, OrderStatus.packing);
      await tester.pumpWidget(const SizedBox());
    });

    test('order cancelled by store/customer releases the busy rider', () async {
      final rider = await newRider();
      svc.seedOrder(order('cancel-1', status: OrderStatus.packing, stage: null));
      await svc.assignRiderToOrder(orderId: 'cancel-1', riderId: rider.id);
      await session.debugSignIn(rider);
      expect(session.rider!.isBusy, isTrue);

      await svc.updateOrderStatus('cancel-1', OrderStatus.cancelled, cancelledBy: 'store', cancellationReason: 'Out of stock');
      await session.refresh(force: true);
      expect(session.rider!.activeOrderId, isNull);
      expect(session.rider!.isBusy, isFalse);
      expect(session.cancelledDeliveries.map((o) => o.id), contains('cancel-1'));
    });

    test('a rider stuck "busy" with an order no longer assigned to them is freed after a grace period', () async {
      var now = DateTime.now();
      session.clock = () => now;
      final created = await newRider();
      // Stuck state from a lost assignment: rider marked busy with an order that
      // isn't assigned to them anywhere.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('qb_rider_status_${created.id}', 'busy');
      await prefs.setString('qb_rider_active_order_${created.id}', 'ghost-order-1');
      final rider = (await svc.getDeliveryPartners()).firstWhere((r) => r.id == created.id);
      expect(rider.activeOrderId, 'ghost-order-1');
      await session.debugSignIn(rider);
      expect(session.rider!.isBusy, isTrue, reason: 'still within grace period');

      now = now.add(RiderSession.orphanGrace + const Duration(seconds: 1));
      await session.refresh(force: true);
      expect(session.rider!.activeOrderId, isNull);
      expect(session.rider!.isBusy, isFalse);
    });

    test('issue report flags the order for the store; only the assigned rider can report', () async {
      final rider = await newRider();
      final other = await newRider();
      svc.seedOrder(order('issue-1', riderId: rider.id, status: OrderStatus.outForDelivery, stage: 'out_for_delivery'));
      expect(await svc.reportDeliveryIssue(orderId: 'issue-1', riderId: other.id, reason: 'x'), isFalse);

      await session.debugSignIn(rider);
      await session.reportIssue(session.orderById('issue-1')!, 'Customer not reachable', 'Called 3 times');
      expect(svc.getOrderById('issue-1')?.deliveryStage, 'issue_reported');
      expect(await svc.getReportedIssue('issue-1'), contains('Customer not reachable'));
    });

    test('cannot go offline or log out with an active delivery', () async {
      final rider = await newRider();
      svc.seedOrder(order('busy-1', riderId: rider.id, status: OrderStatus.outForDelivery, stage: 'out_for_delivery'));
      await session.debugSignIn(rider);
      expect(await session.setOnline(false), isNotNull);
      expect(await session.logout(), isNotNull);
      expect(session.isLoggedIn, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('Earnings & performance', () {
    test('earnings = ₹40 per delivery + tips; COD cash tracked; acceptance includes declines', () async {
      final rider = await newRider();
      final today = DateTime.now();
      svc.seedOrder(order('e1', riderId: rider.id, status: OrderStatus.delivered, stage: 'delivered', tip: 20, payment: 'cod',
          createdAt: today.subtract(const Duration(minutes: 15)), deliveredAt: today));
      svc.seedOrder(order('e2', riderId: rider.id, status: OrderStatus.delivered, stage: 'delivered', payment: 'upi',
          createdAt: today.subtract(const Duration(minutes: 90)), deliveredAt: today.subtract(const Duration(minutes: 30))));
      svc.seedOrder(order('e3', status: OrderStatus.packing, stage: null));
      await svc.assignRiderToOrder(orderId: 'e3', riderId: rider.id);
      await svc.rejectOrderAssignment('e3', rider.id, reason: 'Too far');
      await session.debugSignIn(rider);

      final day = session.earnings(RiderPeriod.day);
      expect(day.count, 2);
      expect(day.deliveryPay, 2 * DeliveryConfig.defaultPerDeliveryEarning);
      expect(day.tips, 20);
      expect(day.total, 2 * DeliveryConfig.defaultPerDeliveryEarning + 20);
      expect(day.buckets.fold<double>(0, (s, b) => s + b.amount), day.total);
      expect(session.earnings(RiderPeriod.week).total, greaterThanOrEqualTo(day.total));
      expect(session.earnings(RiderPeriod.month).total, greaterThanOrEqualTo(day.total));

      expect(session.codCashToday, 486);
      final perf = session.performance;
      expect(perf.acceptanceRate, closeTo(2 / 3, 0.001)); // 2 accepted, 1 declined
      expect(perf.onTimeRate, 0.5); // e2 took 60 min vs 12 + 10 grace
      expect(perf.completionRate, 1.0);
      expect(session.notifications.any((n) => n.kind == 'cash'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('Every screen renders without overflow', () {
    Future<void> seedRealistic() async {
      final rider = (await svc.getDeliveryPartners()).firstWhere((r) => r.id == 'rider-001');
      await svc.updateDeliveryPartnerStatus(rider.id, DeliveryPartnerStatus.online);
      final now = DateTime.now();
      svc.seedOrder(order('s-req', status: OrderStatus.packing, stage: null, tip: 20));
      await svc.assignRiderToOrder(orderId: 's-req', riderId: rider.id);
      for (final (id, stage) in [('s-acc', 'accepted'), ('s-store', 'reached_store'), ('s-out', 'out_for_delivery')]) {
        svc.seedOrder(order(id, riderId: rider.id, status: stage == 'out_for_delivery' ? OrderStatus.outForDelivery : OrderStatus.partnerAssigned, stage: stage));
      }
      svc.seedOrder(order('s-done', riderId: rider.id, status: OrderStatus.delivered, stage: 'delivered', tip: 30,
          createdAt: now.subtract(const Duration(minutes: 20)), deliveredAt: now));
      svc.seedOrder(order('s-cancel', riderId: rider.id, status: OrderStatus.cancelled, stage: 'accepted', withItems: false)
          .copyWith(cancellationReason: 'Customer cancelled', cancelledAt: now));
      await session.debugSignIn((await svc.getDeliveryPartners()).firstWhere((r) => r.id == 'rider-001'));
    }

    final screens = <String, Widget Function()>{
      'home': () => const RiderShell(autoOpenRequests: false),
      'orders tab': () => const RiderShell(initialTab: 1, autoOpenRequests: false),
      'earnings tab': () => const RiderShell(initialTab: 2, autoOpenRequests: false),
      'profile tab': () => const RiderShell(initialTab: 3, autoOpenRequests: false),
      'notifications': () => const RiderNotificationsScreen(),
      'request': () => const NewDeliveryRequestScreen(orderId: 's-req'),
      'order details': () => const RiderOrderDetailsScreen(orderId: 's-out'),
      'accepted': () => const AcceptedOrderScreen(orderId: 's-acc'),
      'store pickup': () => const StorePickupScreen(orderId: 's-store'),
      'pickup confirm': () => const PickupConfirmationScreen(orderId: 's-store'),
      'customer delivery': () => const CustomerDeliveryScreen(orderId: 's-out'),
      'map': () => const MapNavigationScreen(orderId: 's-out'),
      'otp': () => const DeliveryOtpScreen(orderId: 's-out'),
      'success': () => const DeliverySuccessScreen(orderId: 's-done'),
      'issue': () => const DeliveryIssueScreen(orderId: 's-out'),
      'history detail': () => const RiderOrderHistoryDetailScreen(orderId: 's-done'),
      'cancelled detail': () => const RiderOrderHistoryDetailScreen(orderId: 's-cancel'),
      'transactions': () => const RiderTransactionsScreen(),
      'cash': () => const RiderCashCollectedScreen(),
      'personal info': () => const RiderPersonalInfoScreen(),
      'vehicle': () => const RiderVehicleScreen(),
      'documents': () => const RiderDocumentsScreen(),
      'bank': () => const RiderBankScreen(),
      'support': () => const RiderSupportScreen(),
      'login': () => const RiderLoginScreen(autoRestore: false),
    };

    for (final size in const [Size(360, 740), Size(412, 915)]) {
      for (final entry in screens.entries) {
        testWidgets('${entry.key} @ ${size.width.toInt()}w', (tester) async {
          _phone(tester, size);
          await seedRealistic();
          await tester.pumpWidget(_app(entry.value()));
          await _settle(tester);
          expect(tester.takeException(), isNull);
          final scrollables = find.byType(Scrollable);
          if (scrollables.evaluate().isNotEmpty) {
            await tester.drag(scrollables.first, const Offset(0, -2000), warnIfMissed: false);
            await _settle(tester);
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  });
}

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light(googleFonts: false), home: home);

void _phone(WidgetTester tester, [Size size = const Size(390, 844)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// Real Roboto + Material Icons (from the Flutter SDK) so overflow checks match
/// devices; the default test font draws every glyph as a full em square.
Future<void> _loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final file = File('${dir.path}/$f');
      if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }

  await load('Roboto', ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-black.ttf']);
  await load('MaterialIcons', ['materialicons-regular.otf']);
}
