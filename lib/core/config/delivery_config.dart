/// Centralized Delivery & Dark Store Configuration
///
/// Encapsulates all dark store defaults, rider payout constants, and security thresholds.
/// Values can be overridden via Dart compile-time environment flags (--dart-define) or database tables,
/// preventing hardcoded coordinates, earnings, or phone numbers in UI logic.
class DeliveryConfig {
  DeliveryConfig._();

  /// Default Dark Store coordinates and metadata (can be overridden via environment or DB)
  static final double defaultStoreLatitude = double.tryParse(
    const String.fromEnvironment('STORE_DEFAULT_LAT', defaultValue: '17.5186'),
  ) ?? 17.5186;

  static final double defaultStoreLongitude = double.tryParse(
    const String.fromEnvironment('STORE_DEFAULT_LNG', defaultValue: '78.3845'),
  ) ?? 78.3845;

  static const String defaultStorePincode = String.fromEnvironment(
    'STORE_DEFAULT_PINCODE',
    defaultValue: '500090',
  );

  static const String defaultStoreName = String.fromEnvironment(
    'STORE_DEFAULT_NAME',
    defaultValue: 'Nizampet Dark Store',
  );

  /// Delivery partner earning per completed delivery
  static final double defaultPerDeliveryEarning = double.tryParse(
    const String.fromEnvironment('RIDER_PER_DELIVERY_EARNING', defaultValue: '40.0'),
  ) ?? 40.0;

  /// Maximum allowed failed OTP attempts before delivery lockout
  static const int maxOtpAttempts = 3;

  /// OTP expiration duration from order creation
  static const Duration otpExpiryDuration = Duration(hours: 2);
}
