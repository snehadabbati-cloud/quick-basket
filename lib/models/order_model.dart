import 'cart_item_model.dart';
import 'address_model.dart';

enum OrderStatus {
  placed,
  confirmed,
  packing,
  partnerAssigned,
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
      case OrderStatus.partnerAssigned:
        return 'partner_assigned';
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
      case OrderStatus.partnerAssigned:
        return 'Partner Assigned';
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
      case 'partner_assigned':
      case 'partnerassigned':
      case 'assigned':
        return OrderStatus.partnerAssigned;
      case 'out_for_delivery':
      case 'outfordelivery':
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

  // Delivery Partner (Rider) Fields
  final String? riderId;
  final String? riderName;
  final String? riderPhone;
  final String? riderVehicleNumber;
  final String? deliveryStage; // 'assigned', 'accepted', 'reached_store', 'picked_up', 'out_for_delivery', 'delivered'
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final int otpAttempts;
  final DateTime? otpExpiresAt;

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
    this.riderId,
    this.riderName,
    this.riderPhone,
    this.riderVehicleNumber,
    this.deliveryStage,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.otpAttempts = 0,
    this.otpExpiresAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCod =>
      paymentMethod.toLowerCase() == 'cod' ||
      paymentMethod.toLowerCase().contains('cash');
  bool get isPaidOnline => !isCod;

  /// Returns an application-level sanitized copy of this order for the Rider Interface.
  /// The plain-text delivery OTP is stripped to guarantee confidential doorstep verification.
  OrderModel toRiderView() {
    return copyWith(
      deliveryOtp: '',
    );
  }

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
      riderId: json['rider_id'] as String?,
      riderName: json['rider_name'] as String?,
      riderPhone: json['rider_phone'] as String?,
      riderVehicleNumber: json['rider_vehicle'] as String? ?? json['rider_vehicle_number'] as String?,
      deliveryStage: json['delivery_stage'] as String?,
      assignedAt: json['assigned_at'] != null ? DateTime.tryParse(json['assigned_at'] as String) : null,
      pickedUpAt: json['picked_up_at'] != null ? DateTime.tryParse(json['picked_up_at'] as String) : null,
      deliveredAt: json['delivered_at'] != null ? DateTime.tryParse(json['delivered_at'] as String) : null,
      otpAttempts: (json['otp_attempts'] as num?)?.toInt() ?? 0,
      otpExpiresAt: json['otp_expires_at'] != null ? DateTime.tryParse(json['otp_expires_at'] as String) : null,
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
      if (riderId != null) 'rider_id': riderId,
      if (riderName != null) 'rider_name': riderName,
      if (riderPhone != null) 'rider_phone': riderPhone,
      if (riderVehicleNumber != null) 'rider_vehicle': riderVehicleNumber,
      if (deliveryStage != null) 'delivery_stage': deliveryStage,
      if (assignedAt != null) 'assigned_at': assignedAt!.toIso8601String(),
      if (pickedUpAt != null) 'picked_up_at': pickedUpAt!.toIso8601String(),
      if (deliveredAt != null) 'delivered_at': deliveredAt!.toIso8601String(),
      'otp_attempts': otpAttempts,
      if (otpExpiresAt != null) 'otp_expires_at': otpExpiresAt!.toIso8601String(),
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
    String? riderId,
    String? riderName,
    String? riderPhone,
    String? riderVehicleNumber,
    String? deliveryStage,
    DateTime? assignedAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
    int? otpAttempts,
    DateTime? otpExpiresAt,
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
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      riderPhone: riderPhone ?? this.riderPhone,
      riderVehicleNumber: riderVehicleNumber ?? this.riderVehicleNumber,
      deliveryStage: deliveryStage ?? this.deliveryStage,
      assignedAt: assignedAt ?? this.assignedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      otpAttempts: otpAttempts ?? this.otpAttempts,
      otpExpiresAt: otpExpiresAt ?? this.otpExpiresAt,
    );
  }
}
