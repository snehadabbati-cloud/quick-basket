import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_basket/features/admin/screens/admin_dashboard_screen.dart';
import 'package:quick_basket/features/admin/widgets/admin_order_details_dialog.dart';
import 'package:quick_basket/features/admin/widgets/admin_orders_logic.dart';
import 'package:quick_basket/features/admin/widgets/assign_rider_dialog.dart';
import 'package:quick_basket/features/rider/controllers/rider_session.dart';
import 'package:quick_basket/models/delivery_partner_model.dart';
import 'package:quick_basket/models/order_model.dart';
import 'package:quick_basket/services/supabase_service.dart';

/// Admin Panel ↔ rider fulfilment: the store accepts, packs and assigns a
/// rider; only the rider's app can pick up and complete (customer OTP).
void main() {
  final svc = SupabaseService();
  var seq = 0;

  setUpAll(_loadRealFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RiderSession().resetForTest();
  });

  void useSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<DeliveryPartnerModel> rider({bool online = true}) async {
    seq++;
    final r = await svc.addDeliveryPartner(name: 'Flow Rider $seq', phone: '+91 91111 ${(20000 + seq)}', vehicleNumber: 'TS 01 FL $seq');
    if (online) await svc.updateDeliveryPartnerStatus(r.id, DeliveryPartnerStatus.online);
    return (await svc.getDeliveryPartners()).firstWhere((x) => x.id == r.id);
  }

  OrderModel order(String id, OrderStatus status, {String? riderId, String? stage}) => OrderModel(
        id: id,
        orderNumber: '#QB-${700000 + id.hashCode.abs() % 99999}',
        userId: 'cust-$id',
        items: [],
        itemTotal: 300,
        grandTotal: 300,
        status: status,
        deliveryOtp: '5555',
        riderId: riderId,
        riderName: riderId != null ? 'Flow Rider' : null,
        deliveryStage: stage,
      );

  group('OrderFlow (what the store can do next)', () {
    test('store accepts and packs, then assigns a rider; it never dispatches or delivers', () {
      expect(OrderFlow.step(order('a', OrderStatus.placed)), AdminStep.accept);
      expect(OrderFlow.step(order('b', OrderStatus.confirmed)), AdminStep.startPacking);
      expect(OrderFlow.step(order('c', OrderStatus.packing)), AdminStep.assignRider);
      expect(OrderFlow.step(order('d', OrderStatus.partnerAssigned, riderId: 'r', stage: 'accepted')), AdminStep.trackRider);
      expect(OrderFlow.step(order('e', OrderStatus.outForDelivery, riderId: 'r', stage: 'out_for_delivery')), AdminStep.trackRider);
      expect(OrderFlow.step(order('f', OrderStatus.outForDelivery, riderId: 'r', stage: 'issue_reported')), AdminStep.resolveIssue);
      expect(OrderFlow.step(order('g', OrderStatus.outForDelivery)), AdminStep.assignRider); // legacy: no rider
      expect(OrderFlow.step(order('h', OrderStatus.delivered)), AdminStep.none);

      expect(OrderFlow.next(OrderStatus.packing), isNull);
      expect(OrderFlow.next(OrderStatus.partnerAssigned), isNull);
      expect(OrderFlow.next(OrderStatus.outForDelivery), isNull);
      expect(OrderFlow.stepLabel(order('c2', OrderStatus.packing)), 'Assign rider');
      expect(OrderFlow.riderProgress(order('d2', OrderStatus.partnerAssigned, riderId: 'r', stage: 'reached_store')),
          'Flow Rider · At the store, checking items');
    });
  });

  group('Service', () {
    test('reassigning frees the previous rider', () async {
      final first = await rider();
      final second = await rider();
      svc.seedOrder(order('re-1', OrderStatus.packing));
      await svc.assignRiderToOrder(orderId: 're-1', riderId: first.id);
      await svc.assignRiderToOrder(orderId: 're-1', riderId: second.id);

      final riders = await svc.getDeliveryPartners();
      final a = riders.firstWhere((r) => r.id == first.id);
      final b = riders.firstWhere((r) => r.id == second.id);
      expect(a.activeOrderId, isNull);
      expect(a.isAvailableForAssignment, isTrue);
      expect(b.activeOrderId, 're-1');
      expect(svc.getOrderById('re-1')?.riderId, second.id);
    });

    test('store unassign returns the order to packing without hurting the rider\'s acceptance rate', () async {
      final r = await rider();
      svc.seedOrder(order('un-1', OrderStatus.packing));
      await svc.assignRiderToOrder(orderId: 'un-1', riderId: r.id);
      expect(await svc.unassignRider('un-1'), isTrue);

      expect(svc.getOrderById('un-1')?.status, OrderStatus.packing);
      expect(svc.getOrderById('un-1')?.riderId, isNull);
      final freed = (await svc.getDeliveryPartners()).firstWhere((x) => x.id == r.id);
      expect(freed.isAvailableForAssignment, isTrue);
      expect(await svc.getRiderRejectionCount(r.id), 0);
    });
  });

  group('Order details dialog', () {
    Future<void> openDetails(WidgetTester tester, OrderModel o) async {
      useSize(tester, const Size(1200, 1000));
      svc.seedOrder(o);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) {
        return Center(
          child: ElevatedButton(
            onPressed: () => AdminOrderDetailsDialog.show(context, order: o, onOrderUpdated: () {}),
            child: const Text('open'),
          ),
        );
      }))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('packed order without a rider offers Assign Rider, not Dispatch / admin OTP', (tester) async {
      await openDetails(tester, order('dd-1', OrderStatus.packing));
      expect(find.text('Assign Rider'), findsWidgets);
      expect(find.textContaining('Handover'), findsNothing);
      expect(find.textContaining('Dispatch'), findsNothing);
      expect(find.textContaining('Verify Delivery OTP'), findsNothing);

      await tester.tap(find.text('Assign Rider').last);
      await tester.pumpAndSettle();
      expect(find.text('Assign Delivery Partner'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('out for delivery with a rider: admin can only track; the rider completes with OTP', (tester) async {
      final r = await rider();
      await openDetails(tester, order('dd-2', OrderStatus.outForDelivery, riderId: r.id, stage: 'out_for_delivery'));
      expect(find.byKey(const ValueKey('admin_rider_driven_status')), findsOneWidget);
      expect(find.textContaining('Verify Delivery OTP'), findsNothing);
      expect(find.textContaining('Mark Delivered'), findsNothing);
      expect(find.text('Flow Rider · On the way to the customer'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('rider-reported issue is highlighted with Reassign', (tester) async {
      final r = await rider();
      await openDetails(tester, order('dd-3', OrderStatus.outForDelivery, riderId: r.id, stage: 'issue_reported'));
      expect(find.text('Rider reported an issue — Reassign rider'), findsOneWidget);
      expect(find.text('Flow Rider · Issue reported by rider'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('assign dialog explains when no rider is online', (tester) async {
    useSize(tester, const Size(1200, 1000));
    // Every registered rider offline (built-in test riders default to offline).
    for (final r in await svc.getDeliveryPartners()) {
      await svc.updateDeliveryPartnerStatus(r.id, DeliveryPartnerStatus.offline);
    }
    final o = order('nr-1', OrderStatus.packing);
    svc.seedOrder(o);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: AssignRiderDialog(order: o)))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('no_riders_online')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('End to end: admin accepts → packs → assigns; rider picks up and completes with OTP', (tester) async {
    useSize(tester, const Size(1440, 2400)); // tall enough that every board card is on screen
    final r = await rider();
    final o = order('e2e-admin-1', OrderStatus.placed);
    svc.seedOrder(o);

    await tester.pumpWidget(const MaterialApp(
      home: AdminDashboardScreen(managerData: {'name': 'Store Manager', 'email': 'manager@quickbasket.com'}),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Live Orders').first);
    await tester.pumpAndSettle();

    Future<void> act(String label) async {
      final card = find.byKey(ValueKey('order_card_${o.id}'));
      final button = find.descendant(of: card, matching: find.text(label));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    // Store: accept, start packing
    await act('Accept order');
    expect(svc.getOrderById(o.id)?.status, OrderStatus.confirmed);
    await act('Start packing');
    expect(svc.getOrderById(o.id)?.status, OrderStatus.packing);

    // Store: assign rider (opens the picker)
    await act('Assign rider');
    expect(find.text('Assign Delivery Partner'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('rider_select_${r.id}')));
    await tester.pump();
    await tester.tap(find.text('Confirm Assignment'));
    await tester.pumpAndSettle();
    expect(svc.getOrderById(o.id)?.status, OrderStatus.partnerAssigned);
    expect(svc.getOrderById(o.id)?.riderId, r.id);
    expect(find.text('Track rider'), findsWidgets);

    // Rider (their app): accept → at store → pickup → OTP
    final session = RiderSession();
    await session.debugSignIn((await svc.getDeliveryPartners()).firstWhere((x) => x.id == r.id));
    final mine = session.orderById(o.id)!;
    await session.accept(mine);
    await session.reachedStore(mine);
    await session.confirmPickup(mine);
    expect(svc.getOrderById(o.id)?.status, OrderStatus.outForDelivery);
    final res = await session.verifyDeliveryOtp(mine, '5555');
    expect(res['success'], isTrue);
    expect(svc.getOrderById(o.id)?.status, OrderStatus.delivered);

    await tester.pumpWidget(const SizedBox());
  });
}

/// Real Roboto + Material Icons from the Flutter SDK (the default test font
/// draws every glyph as a full square and exaggerates widths).
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
