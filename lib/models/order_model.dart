import 'cart_item_model.dart';
import 'address_model.dart';

enum OrderStatus {
  placed,
  confirmed,
  packing,
  outForDelivery,
  delivered,
  cancelled,
}

extension OrderStatusExtension on OrderStatus {
  String get value {
    switch (this) {
      case OrderStatus.placed:
        return 'placed';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.packing:
        return 'packing';
      case OrderStatus.outForDelivery:
        return 'out_for_delivery';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  String get displayName {
    switch (this) {
      case OrderStatus.placed:
        return 'Order Placed';
      case OrderStatus.confirmed:
        return 'Order Confirmed';
      case OrderStatus.packing:
        return 'Packing at Dark Store';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  static OrderStatus fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'placed':
      case 'pending':
        return OrderStatus.placed;
      case 'confirmed':
      case 'accepted':
        return OrderStatus.confirmed;
      case 'packing':
      case 'preparing':
      case 'picking_started':
      case 'packed':
        return OrderStatus.packing;
      case 'out_for_delivery':
      case 'outfordelivery':
      case 'partner_assigned':
        return OrderStatus.outForDelivery;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.placed;
    }
  }
}

class OrderModel {
  final String id;
  final String orderNumber;
  final String userId;
  final String storeId;
  final AddressModel? address;
  final List<CartItemModel> items;
  final double itemTotal;
  final double discountAmount;
  final double deliveryFee;
  final double packagingFee;
  final double tipAmount;
  final double grandTotal;
  final String paymentMethod; // 'cod', 'upi'
  final String paymentStatus; // 'pending', 'captured', 'refunded', 'completed'
  final OrderStatus status;
  final String deliveryOtp;
  final String? deliveryInstructions;
  final String? cancelledBy; // 'customer' or 'store'
  final String? cancellationReason;
  final DateTime? cancelledAt;
  final String? refundStatus; // 'none', 'pending', 'initiated', 'processed'
  final DateTime createdAt;
  final int estimatedDeliveryMinutes;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.userId,
    this.storeId = '11111111-1111-1111-1111-111111111111',
    this.address,
    required this.items,
    required this.itemTotal,
    this.discountAmount = 0.0,
    this.deliveryFee = 0.0,
    this.packagingFee = 5.0,
    this.tipAmount = 0.0,
    required this.grandTotal,
    this.paymentMethod = 'cod',
    this.paymentStatus = 'pending',
    this.status = OrderStatus.placed,
    this.deliveryOtp = '4921',
    this.deliveryInstructions,
    this.cancelledBy,
    this.cancellationReason,
    this.cancelledAt,
    this.refundStatus,
    DateTime? createdAt,
    this.estimatedDeliveryMinutes = 12,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCod => paymentMethod.toLowerCase() == 'cod';
  bool get isPaidOnline => !isCod;

  /// Returns the exact user-facing refund message per PRD & user rules
  String get refundStatusMessage {
    if (isCod) {
      return 'No payment was collected for this order.';
    }
    switch ((refundStatus ?? '').toLowerCase().trim()) {
      case 'initiated':
        return 'Your refund has been initiated.';
      case 'processed':
        return 'Your refund has been successfully processed.';
      case 'pending':
        return 'Your refund is being processed.';
      default:
        return '';
    }
  }

  factory OrderModel.fromJson(Map<String, dynamic> json, {List<CartItemModel> items = const [], AddressModel? address}) {
    return OrderModel(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String? ?? '#QB-0000',
      userId: json['user_id'] as String? ?? '',
      storeId: json['store_id'] as String? ?? '11111111-1111-1111-1111-111111111111',
      address: address,
      items: items,
      itemTotal: (json['item_total'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      packagingFee: (json['taxes'] as num?)?.toDouble() ?? 5.0,
      grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? 'cod',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      status: OrderStatusExtension.fromString(json['order_status'] as String? ?? 'placed'),
      deliveryOtp: json['delivery_otp'] as String? ?? '4921',
      deliveryInstructions: json['delivery_instructions'] as String?,
      cancelledBy: json['cancelled_by'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      cancelledAt: json['cancelled_at'] != null ? DateTime.tryParse(json['cancelled_at'] as String) : null,
      refundStatus: json['refund_status'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'user_id': userId,
      'store_id': storeId,
      'item_total': itemTotal,
      'discount_amount': discountAmount,
      'delivery_fee': deliveryFee,
      'taxes': packagingFee,
      'grand_total': grandTotal,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'order_status': status.value,
      'delivery_otp': deliveryOtp,
      'delivery_instructions': deliveryInstructions,
      'cancelled_by': cancelledBy,
      'cancellation_reason': cancellationReason,
      'cancelled_at': cancelledAt?.toIso8601String(),
      'refund_status': refundStatus,
      'created_at': createdAt.toIso8601String(),
      'estimated_delivery_minutes': estimatedDeliveryMinutes,
    };
  }

  OrderModel copyWith({
    String? id,
    String? orderNumber,
    String? userId,
    String? storeId,
    AddressModel? address,
    List<CartItemModel>? items,
    double? itemTotal,
    double? discountAmount,
    double? deliveryFee,
    double? packagingFee,
    double? tipAmount,
    double? grandTotal,
    String? paymentMethod,
    String? paymentStatus,
    OrderStatus? status,
    String? deliveryOtp,
    String? deliveryInstructions,
    String? cancelledBy,
    String? cancellationReason,
    DateTime? cancelledAt,
    String? refundStatus,
    DateTime? createdAt,
    int? estimatedDeliveryMinutes,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      userId: userId ?? this.userId,
      storeId: storeId ?? this.storeId,
      address: address ?? this.address,
      items: items ?? this.items,
      itemTotal: itemTotal ?? this.itemTotal,
      discountAmount: discountAmount ?? this.discountAmount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      packagingFee: packagingFee ?? this.packagingFee,
      tipAmount: tipAmount ?? this.tipAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      status: status ?? this.status,
      deliveryOtp: deliveryOtp ?? this.deliveryOtp,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      refundStatus: refundStatus ?? this.refundStatus,
      createdAt: createdAt ?? this.createdAt,
      estimatedDeliveryMinutes: estimatedDeliveryMinutes ?? this.estimatedDeliveryMinutes,
    );
  }
}
