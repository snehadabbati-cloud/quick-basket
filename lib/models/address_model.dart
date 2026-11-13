class AddressModel {
  final String id;
  final String userId;
  final String type; // 'Home', 'Work', 'Other'
  final String flatHouseNumber;
  final String areaStreet;
  final String? landmark;
  final String city;
  final String pincode;
  final bool isDefault;
  final DateTime createdAt;

  AddressModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.flatHouseNumber,
    required this.areaStreet,
    this.landmark,
    this.city = 'Bengaluru',
    this.pincode = '560001',
    this.isDefault = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get formattedAddress {
    final parts = [flatHouseNumber, areaStreet];
    if (landmark != null && landmark!.isNotEmpty) {
      parts.add('Near $landmark');
    }
    parts.add('$city - $pincode');
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
      city: json['city'] as String? ?? 'Bengaluru',
      pincode: json['pincode'] as String? ?? '560001',
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
      'pincode': pincode,
      'is_default': isDefault,
    };
  }
}
