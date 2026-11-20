import 'package:flutter/foundation.dart';

/// Operational availability status for a Delivery Partner
enum DeliveryPartnerStatus {
  offline, // Default state for all new riders per PRD & user rules
  online,
  busy,
}

extension DeliveryPartnerStatusExtension on DeliveryPartnerStatus {
  String get value {
    switch (this) {
      case DeliveryPartnerStatus.offline:
        return 'offline';
      case DeliveryPartnerStatus.online:
        return 'online';
      case DeliveryPartnerStatus.busy:
        return 'busy';
    }
  }

  String get displayName {
    switch (this) {
      case DeliveryPartnerStatus.offline:
        return 'Offline';
      case DeliveryPartnerStatus.online:
        return 'Online';
      case DeliveryPartnerStatus.busy:
        return 'On Delivery';
    }
  }

  static DeliveryPartnerStatus fromString(String? val) {
    switch ((val ?? '').toLowerCase().trim()) {
      case 'online':
        return DeliveryPartnerStatus.online;
      case 'busy':
        return DeliveryPartnerStatus.busy;
      case 'offline':
      default:
        // New riders strictly default to offline
        return DeliveryPartnerStatus.offline;
    }
  }
}

/// Delivery Partner (Rider) Data Model
@immutable
class DeliveryPartnerModel {
  final String id;
  final String? userId; // References auth.users / profiles
  final String? storeId; // References dark store hub
  final String name;
  final String phone;
  final String vehicleNumber;
  final String vehicleType; // 'bike', 'scooter', 'ev'
  final DeliveryPartnerStatus status;
  final double currentLatitude;
  final double currentLongitude;
  final double rating;
  final int totalDeliveries;
  final String? activeOrderId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DeliveryPartnerModel({
    required this.id,
    this.userId,
    this.storeId,
    required this.name,
    required this.phone,
    required this.vehicleNumber,
    this.vehicleType = 'bike',
    this.status = DeliveryPartnerStatus.offline, // Default to offline!
    this.currentLatitude = 17.5186,
    this.currentLongitude = 78.3845,
    this.rating = 5.0,
    this.totalDeliveries = 0,
    this.activeOrderId,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isOnline => status == DeliveryPartnerStatus.online;
  bool get isOffline => status == DeliveryPartnerStatus.offline;
  bool get isBusy => status == DeliveryPartnerStatus.busy;
  bool get isAvailableForAssignment => status == DeliveryPartnerStatus.online && activeOrderId == null;
  bool get isAvailable => isAvailableForAssignment;

  factory DeliveryPartnerModel.fromJson(Map<String, dynamic> json) {
    return DeliveryPartnerModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      storeId: json['store_id'] as String?,
      name: json['name'] as String? ?? 'Delivery Partner',
      phone: json['phone'] as String? ?? '',
      vehicleNumber: json['vehicle_number'] as String? ?? '',
      vehicleType: json['vehicle_type'] as String? ?? 'bike',
      status: DeliveryPartnerStatusExtension.fromString(json['status'] as String?),
      currentLatitude: (json['current_lat'] as num?)?.toDouble() ?? 17.5186,
      currentLongitude: (json['current_lng'] as num?)?.toDouble() ?? 78.3845,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      totalDeliveries: (json['total_deliveries'] as num?)?.toInt() ?? 0,
      activeOrderId: json['active_order_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      if (storeId != null) 'store_id': storeId,
      'name': name,
      'phone': phone,
      'vehicle_number': vehicleNumber,
      'vehicle_type': vehicleType,
      'status': status.value,
      'current_lat': currentLatitude,
      'current_lng': currentLongitude,
      'rating': rating,
      'total_deliveries': totalDeliveries,
      if (activeOrderId != null) 'active_order_id': activeOrderId,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  DeliveryPartnerModel copyWith({
    String? id,
    String? userId,
    String? storeId,
    String? name,
    String? phone,
    String? vehicleNumber,
    String? vehicleType,
    DeliveryPartnerStatus? status,
    double? currentLatitude,
    double? currentLongitude,
    double? rating,
    int? totalDeliveries,
    String? activeOrderId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryPartnerModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      status: status ?? this.status,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      activeOrderId: activeOrderId ?? this.activeOrderId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
