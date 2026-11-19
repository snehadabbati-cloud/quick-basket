import 'dart:math';

/// Delivery Area & Geofencing Model (PRD Section 4.2 & 5.12)
/// Centered around Pincode 500090 (Nizampet, Telangana)
class DeliveryAreaModel {
  final String id;
  final String storeId;
  final String name; // e.g. "Nizampet & Pragathi Nagar"
  final String pincode; // e.g. "500090"
  final String city; // "Hyderabad"
  final String state; // "Telangana"
  final double minOrderValue; // e.g. 99.0
  final double deliveryFee; // e.g. 25.0
  final double freeDeliveryAbove; // e.g. 199.0
  final int estimatedDeliveryMins; // e.g. 12
  final double latitude;
  final double longitude;
  final double radiusKm; // Service radius around center
  final bool isActive;

  const DeliveryAreaModel({
    required this.id,
    required this.storeId,
    required this.name,
    required this.pincode,
    this.city = 'Hyderabad',
    this.state = 'Telangana',
    this.minOrderValue = 99.0,
    this.deliveryFee = 25.0,
    this.freeDeliveryAbove = 199.0,
    this.estimatedDeliveryMins = 12,
    required this.latitude,
    required this.longitude,
    this.radiusKm = 3.5,
    this.isActive = true,
  });

  factory DeliveryAreaModel.fromJson(Map<String, dynamic> json) {
    return DeliveryAreaModel(
      id: json['id'] as String,
      storeId: json['store_id'] as String? ?? 'store-500090-hub',
      name: json['name'] as String,
      pincode: json['pincode'] as String,
      city: json['city'] as String? ?? 'Hyderabad',
      state: json['state'] as String? ?? 'Telangana',
      minOrderValue: (json['min_order_value'] as num?)?.toDouble() ?? 99.0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 25.0,
      freeDeliveryAbove: (json['free_delivery_above'] as num?)?.toDouble() ?? 199.0,
      estimatedDeliveryMins: (json['estimated_delivery_mins'] as num?)?.toInt() ?? 12,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 17.5186,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 78.3845,
      radiusKm: (json['radius_km'] as num?)?.toDouble() ?? 3.5,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_id': storeId,
      'name': name,
      'pincode': pincode,
      'city': city,
      'state': state,
      'min_order_value': minOrderValue,
      'delivery_fee': deliveryFee,
      'free_delivery_above': freeDeliveryAbove,
      'estimated_delivery_mins': estimatedDeliveryMins,
      'latitude': latitude,
      'longitude': longitude,
      'radius_km': radiusKm,
      'is_active': isActive,
    };
  }

  DeliveryAreaModel copyWith({
    String? id,
    String? storeId,
    String? name,
    String? pincode,
    String? city,
    String? state,
    double? minOrderValue,
    double? deliveryFee,
    double? freeDeliveryAbove,
    int? estimatedDeliveryMins,
    double? latitude,
    double? longitude,
    double? radiusKm,
    bool? isActive,
  }) {
    return DeliveryAreaModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      pincode: pincode ?? this.pincode,
      city: city ?? this.city,
      state: state ?? this.state,
      minOrderValue: minOrderValue ?? this.minOrderValue,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      freeDeliveryAbove: freeDeliveryAbove ?? this.freeDeliveryAbove,
      estimatedDeliveryMins: estimatedDeliveryMins ?? this.estimatedDeliveryMins,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusKm: radiusKm ?? this.radiusKm,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Result of evaluating an address or coordinates against the dark store serviceability engine
class ServiceabilityResult {
  final bool isServiceable;
  final DeliveryAreaModel? matchedArea;
  final int estimatedMinutes;
  final double deliveryFee;
  final double minOrderValue;
  final double freeDeliveryAbove;
  final double? distanceKm;
  final String statusHeadline;
  final String statusMessage;

  const ServiceabilityResult({
    required this.isServiceable,
    this.matchedArea,
    this.estimatedMinutes = 12,
    this.deliveryFee = 25.0,
    this.minOrderValue = 99.0,
    this.freeDeliveryAbove = 199.0,
    this.distanceKm,
    required this.statusHeadline,
    required this.statusMessage,
  });

  /// Default serviceable result for 500090
  factory ServiceabilityResult.serviceable(DeliveryAreaModel area, [double? distance]) {
    return ServiceabilityResult(
      isServiceable: true,
      matchedArea: area,
      estimatedMinutes: area.estimatedDeliveryMins,
      deliveryFee: area.deliveryFee,
      minOrderValue: area.minOrderValue,
      freeDeliveryAbove: area.freeDeliveryAbove,
      distanceKm: distance,
      statusHeadline: '${area.estimatedDeliveryMins} Mins Delivery',
      statusMessage: 'Delivering directly from Nizampet Dark Store to ${area.name}',
    );
  }

  /// Unserviceable location outside delivery zones
  factory ServiceabilityResult.unserviceable(String pincode, [double? distance]) {
    return ServiceabilityResult(
      isServiceable: false,
      estimatedMinutes: 0,
      deliveryFee: 0,
      minOrderValue: 0,
      freeDeliveryAbove: 0,
      distanceKm: distance,
      statusHeadline: 'Location Not Serviceable',
      statusMessage: distance != null
          ? 'This location is ${distance.toStringAsFixed(1)} km away (outside our 5 km delivery radius from Nizampet 500090).'
          : 'Pincode $pincode is outside our 10-12 min quick-delivery zones around Nizampet 500090.',
    );
  }
}

/// Dark Store Hub coordinates and configuration
class DarkStoreConfig {
  static const String storeId = 'store-500090-hub';
  static const String storeName = 'Quick Basket Nizampet Dark Store';
  static const String storeAddress = 'Plot 42, Nizampet Road, Pragathi Nagar, Hyderabad, Telangana 500090';
  static const String primaryPincode = '500090';
  static const double storeLatitude = 17.5186;
  static const double storeLongitude = 78.3845;
  static const double maxServiceRadiusKm = 5.5;

  static const String hubPincode = primaryPincode;
  static const String hubCity = 'Hyderabad';
  static const String hubState = 'Telangana';
  static const double hubLatitude = storeLatitude;
  static const double hubLongitude = storeLongitude;
  static const double maxDeliveryRadiusKm = maxServiceRadiusKm;

  static bool isPincodeDeliverable(String pincode) {
    return defaultAreas.any((a) => a.pincode == pincode && a.isActive);
  }

  static int getEstimatedMinutesForPincode(String pincode) {
    final area = defaultAreas.cast<DeliveryAreaModel?>().firstWhere(
      (a) => a?.pincode == pincode,
      orElse: () => null,
    );
    return area?.estimatedDeliveryMins ?? 11;
  }

  /// Default pre-configured delivery areas centered around 500090 (Telangana)
  static final List<DeliveryAreaModel> defaultAreas = [
    const DeliveryAreaModel(
      id: 'area-500090',
      storeId: storeId,
      name: 'Nizampet & Pragathi Nagar',
      pincode: '500090',
      city: 'Hyderabad',
      state: 'Telangana',
      minOrderValue: 99.0,
      deliveryFee: 25.0,
      freeDeliveryAbove: 199.0,
      estimatedDeliveryMins: 11,
      latitude: 17.5186,
      longitude: 78.3845,
      radiusKm: 2.5,
      isActive: true,
    ),
    const DeliveryAreaModel(
      id: 'area-500072',
      storeId: storeId,
      name: 'Kukatpally & KPHB Colony',
      pincode: '500072',
      city: 'Hyderabad',
      state: 'Telangana',
      minOrderValue: 99.0,
      deliveryFee: 25.0,
      freeDeliveryAbove: 199.0,
      estimatedDeliveryMins: 13,
      latitude: 17.4933,
      longitude: 78.3995,
      radiusKm: 3.0,
      isActive: true,
    ),
    const DeliveryAreaModel(
      id: 'area-500085',
      storeId: storeId,
      name: 'JNTU & KPHB Phase 4-9',
      pincode: '500085',
      city: 'Hyderabad',
      state: 'Telangana',
      minOrderValue: 99.0,
      deliveryFee: 25.0,
      freeDeliveryAbove: 199.0,
      estimatedDeliveryMins: 14,
      latitude: 17.5020,
      longitude: 78.3890,
      radiusKm: 2.8,
      isActive: true,
    ),
    const DeliveryAreaModel(
      id: 'area-500049',
      storeId: storeId,
      name: 'Miyapur & Bachupally',
      pincode: '500049',
      city: 'Hyderabad',
      state: 'Telangana',
      minOrderValue: 120.0,
      deliveryFee: 30.0,
      freeDeliveryAbove: 249.0,
      estimatedDeliveryMins: 16,
      latitude: 17.5312,
      longitude: 78.3688,
      radiusKm: 3.8,
      isActive: true,
    ),
    const DeliveryAreaModel(
      id: 'area-500055',
      storeId: storeId,
      name: 'Gajularamaram & Quthbullapur',
      pincode: '500055',
      city: 'Hyderabad',
      state: 'Telangana',
      minOrderValue: 149.0,
      deliveryFee: 35.0,
      freeDeliveryAbove: 299.0,
      estimatedDeliveryMins: 18,
      latitude: 17.5255,
      longitude: 78.4230,
      radiusKm: 4.8,
      isActive: true,
    ),
  ];

  /// Haversine formula to compute great-circle distance between two GPS coordinates in kilometers
  static double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }
}
