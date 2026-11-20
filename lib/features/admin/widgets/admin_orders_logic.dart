import '../../../models/order_model.dart';

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

  static bool isActive(OrderStatus s) => activeStages.contains(s);

  static OrderStatus? next(OrderStatus s) {
    switch (s) {
      case OrderStatus.placed:
        return OrderStatus.confirmed;
      case OrderStatus.confirmed:
        return OrderStatus.packing;
      case OrderStatus.packing:
      case OrderStatus.partnerAssigned:
        return OrderStatus.outForDelivery;
      case OrderStatus.outForDelivery:
        return OrderStatus.delivered;
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
        return 'Handover to rider';
      case OrderStatus.partnerAssigned:
        return 'Dispatch to customer';
      case OrderStatus.outForDelivery:
        return 'Verify OTP & deliver';
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
        return 'Handover';
      case OrderStatus.partnerAssigned:
        return 'Dispatch';
      case OrderStatus.outForDelivery:
        return 'Verify OTP';
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
        return 'handed to a rider';
      case OrderStatus.partnerAssigned:
        return 'dispatched';
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
