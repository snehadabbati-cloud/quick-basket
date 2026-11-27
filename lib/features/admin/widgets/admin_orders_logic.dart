import '../../../models/order_model.dart';

/// What the store can do next with an order (see [OrderFlow.step]).
enum AdminStep { accept, startPacking, assignRider, trackRider, resolveIssue, none }

/// Order fulfilment pipeline used by the admin dashboard and order board.
class OrderFlow {
  OrderFlow._();

  /// Board columns, in order.
  static const List<OrderStatus> activeStages = [
    OrderStatus.placed,
    OrderStatus.confirmed,
    OrderStatus.packing,
    OrderStatus.outForDelivery,
  ];

  static bool isActive(OrderStatus s) => activeStages.contains(s) || s == OrderStatus.partnerAssigned;

  // ---------------------------------------------------------------------------
  // Rider-based fulfilment (order-aware). The store accepts, packs and assigns a
  // rider; the rider's app then moves the order to Out for delivery (pickup)
  // and Delivered (customer OTP). The admin never dispatches or delivers.
  // ---------------------------------------------------------------------------

  static bool hasRider(OrderModel o) => o.riderId != null && o.riderId!.isNotEmpty;
  static bool hasIssue(OrderModel o) => o.deliveryStage == 'issue_reported';

  /// The admin's next action for [o].
  static AdminStep step(OrderModel o) {
    switch (o.status) {
      case OrderStatus.placed:
        return AdminStep.accept;
      case OrderStatus.confirmed:
        return AdminStep.startPacking;
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return AdminStep.none;
      case OrderStatus.packing:
      case OrderStatus.partnerAssigned:
      case OrderStatus.outForDelivery:
        if (!hasRider(o)) return AdminStep.assignRider;
        if (hasIssue(o)) return AdminStep.resolveIssue;
        return AdminStep.trackRider;
    }
  }

  static String stepLabel(OrderModel o) => switch (step(o)) {
        AdminStep.accept => 'Accept order',
        AdminStep.startPacking => 'Start packing',
        AdminStep.assignRider => 'Assign rider',
        AdminStep.resolveIssue => 'Resolve issue',
        AdminStep.trackRider => 'Track rider',
        AdminStep.none => '',
      };

  static String stepShort(OrderModel o) => switch (step(o)) {
        AdminStep.accept => 'Accept',
        AdminStep.startPacking => 'Start packing',
        AdminStep.assignRider => 'Assign rider',
        AdminStep.resolveIssue => 'Resolve issue',
        AdminStep.trackRider => 'Track',
        AdminStep.none => 'View',
      };

  /// One-line hint under the action button.
  static String stepHint(OrderModel o) => switch (step(o)) {
        AdminStep.accept => 'Moves to Confirmed',
        AdminStep.startPacking => 'Moves to Picking & packing',
        AdminStep.assignRider => 'Pick an online rider — they collect it from the store',
        AdminStep.resolveIssue => 'Rider reported a problem — reassign or cancel',
        AdminStep.trackRider => o.status == OrderStatus.outForDelivery
            ? 'Rider completes it with the customer\'s OTP'
            : 'Moves to Out for delivery when the rider picks it up',
        AdminStep.none => '',
      };

  /// Live rider progress, e.g. "Ramesh Kumar · At the store".
  static String riderProgress(OrderModel o) {
    if (!hasRider(o)) return 'No rider assigned';
    final stage = switch (o.deliveryStage ?? 'assigned') {
      'assigned' => 'Waiting for rider to accept',
      'accepted' => 'Heading to the store',
      'reached_store' => 'At the store, checking items',
      'picked_up' => 'Picked up',
      'out_for_delivery' => 'On the way to the customer',
      'issue_reported' => 'Issue reported by rider',
      'delivered' => 'Delivered',
      final s => s,
    };
    return '${o.riderName ?? 'Rider'} · $stage';
  }

  /// Status the *store* moves an order to. Beyond packing, the rider app drives
  /// the order (pickup → Out for delivery, customer OTP → Delivered).
  static OrderStatus? next(OrderStatus s) {
    switch (s) {
      case OrderStatus.placed:
        return OrderStatus.confirmed;
      case OrderStatus.confirmed:
        return OrderStatus.packing;
      case OrderStatus.packing:
      case OrderStatus.partnerAssigned:
      case OrderStatus.outForDelivery:
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return null;
    }
  }

  static String actionLabel(OrderStatus s) {
    switch (s) {
      case OrderStatus.placed:
        return 'Accept order';
      case OrderStatus.confirmed:
        return 'Start packing';
      case OrderStatus.packing:
        return 'Assign rider';
      case OrderStatus.partnerAssigned:
        return 'Track rider';
      case OrderStatus.outForDelivery:
        return 'Track rider';
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return '';
    }
  }

  static String shortAction(OrderStatus s) {
    switch (s) {
      case OrderStatus.placed:
        return 'Accept';
      case OrderStatus.confirmed:
        return 'Start packing';
      case OrderStatus.packing:
        return 'Assign rider';
      case OrderStatus.partnerAssigned:
        return 'Track';
      case OrderStatus.outForDelivery:
        return 'Track';
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return 'View';
    }
  }

  /// Past-tense verb for the action taken from [s].
  static String verb(OrderStatus s) {
    switch (s) {
      case OrderStatus.placed:
        return 'accepted';
      case OrderStatus.confirmed:
        return 'sent for packing';
      case OrderStatus.packing:
        return 'assigned to a rider';
      case OrderStatus.partnerAssigned:
        return 'picked up';
      case OrderStatus.outForDelivery:
        return 'delivered';
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return 'updated';
    }
  }

  static String stageTitle(OrderStatus s) {
    switch (s) {
      case OrderStatus.placed:
        return 'New orders';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.packing:
        return 'Picking & packing';
      case OrderStatus.partnerAssigned:
        return 'Rider assigned';
      case OrderStatus.outForDelivery:
        return 'Out for delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Rejected';
    }
  }
}

/// Delivery instructions without the embedded items payload.
String cleanOrderNote(String? raw) {
  if (raw == null) return '';
  return raw.replaceAll(RegExp(r'\[QB_ITEMS_PAYLOAD\](.*?)\[/QB_ITEMS_PAYLOAD\]', dotAll: true), '').trim();
}

/// The most recent status change made from the admin panel (for feedback + undo).
class AdminOrderAction {
  final String orderId;
  final String orderNumber;
  final String customer;
  final OrderStatus from;
  final OrderStatus to;

  const AdminOrderAction({
    required this.orderId,
    required this.orderNumber,
    required this.customer,
    required this.from,
    required this.to,
  });

  bool get rejected => to == OrderStatus.cancelled;
}
