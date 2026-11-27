import '../../../models/delivery_partner_model.dart';

/// Cleanly isolated test fixtures for delivery partners
/// Separated from production logic per Requirement #6.
class TestRiderFixtures {
  TestRiderFixtures._();

  /// Default test delivery partners (all initialized to Offline per Requirement #5)
  static List<DeliveryPartnerModel> get defaultTestRiders => [
    DeliveryPartnerModel(
      id: 'rider-001',
      name: 'Ramesh Kumar',
      phone: '+91 98765 43210',
      vehicleNumber: 'TS 08 AB 1234',
      vehicleType: 'bike',
      status: DeliveryPartnerStatus.offline, // Strict default offline
      rating: 4.9,
      totalDeliveries: 48,
    ),
    DeliveryPartnerModel(
      id: 'rider-002',
      name: 'Suresh Reddy',
      phone: '+91 98765 43211',
      vehicleNumber: 'TS 08 CD 5678',
      vehicleType: 'scooter',
      status: DeliveryPartnerStatus.offline, // Strict default offline
      rating: 4.8,
      totalDeliveries: 32,
    ),
    DeliveryPartnerModel(
      id: 'rider-003',
      name: 'Vikram Rao',
      phone: '+91 98765 43212',
      vehicleNumber: 'TS 08 EF 9012',
      vehicleType: 'ev',
      status: DeliveryPartnerStatus.offline, // Strict default offline
      rating: 5.0,
      totalDeliveries: 19,
    ),
  ];
}
