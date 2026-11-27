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

  /// Time a rider has to accept a new delivery request before it is
  /// automatically declined and returned to the store pool.
  static const Duration requestResponseWindow = Duration(seconds: 30);

  /// Grace period on top of the promised ETA for a delivery to count as on-time.
  static const Duration onTimeGrace = Duration(minutes: 10);

  /// Dark store support line shown to riders. Empty = not configured (the app
  /// says so instead of dialling a placeholder number).
  static const String storeSupportPhone = String.fromEnvironment('STORE_SUPPORT_PHONE', defaultValue: '');

  /// DEBUG BUILDS ONLY: login code for the built-in test riders
  /// (TestRiderFixtures), whose phone numbers are fictional — no SMS is sent.
  static const String debugTestRiderOtp = '123456';
}
