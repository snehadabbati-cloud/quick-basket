class AddressModel {
  final String id;
  final String userId;
  final String type; // 'Home', 'Work', 'Other'
  final String flatHouseNumber;
  final String areaStreet;
  final String? landmark;
  final String city;
  final String state;
  final String pincode;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final DateTime createdAt;

  AddressModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.flatHouseNumber,
    required this.areaStreet,
    this.landmark,
    this.city = 'Hyderabad',
    this.state = 'Telangana',
    this.pincode = '500090',
    this.latitude,
    this.longitude,
    this.isDefault = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get formattedAddress {
    final parts = [flatHouseNumber, areaStreet];
    if (landmark != null && landmark!.isNotEmpty) {
      parts.add('Near $landmark');
    }
    parts.add('$city, $state - $pincode');
    return parts.join(', ');
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['address_type'] as String? ?? 'Home',
      flatHouseNumber: json['address_line1'] as String? ?? '',
      areaStreet: json['address_line2'] as String? ?? '',
      landmark: json['landmark'] as String?,
      city: json['city'] as String? ?? 'Hyderabad',
      state: json['state'] as String? ?? 'Telangana',
      pincode: json['pincode'] as String? ?? '500090',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'address_type': type,
      'address_line1': flatHouseNumber,
      'address_line2': areaStreet,
      'landmark': landmark,
      'city': city,
      'state': state,
      'pincode': pincode,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'is_default': isDefault,
    };
  }

  AddressModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? flatHouseNumber,
    String? areaStreet,
    String? landmark,
    String? city,
    String? state,
    String? pincode,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) {
    return AddressModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      flatHouseNumber: flatHouseNumber ?? this.flatHouseNumber,
      areaStreet: areaStreet ?? this.areaStreet,
      landmark: landmark ?? this.landmark,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt,
    );
  }
}
