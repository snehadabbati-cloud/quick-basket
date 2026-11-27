import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/delivery_config.dart';
import '../../../models/delivery_partner_model.dart';
import '../../../models/order_model.dart';
import '../../../services/supabase_service.dart';
import '../data/test_rider_fixtures.dart';

/// Thrown for user-facing rider login / action failures.
class RiderException implements Exception {
  final String message;
  const RiderException(this.message);
  @override
  String toString() => message;
}

/// Result of [RiderSession.requestOtp].
class RiderOtpRequest {
  final DeliveryPartnerModel rider;
  final String phoneE164;
  /// True for debug-only test riders: no SMS is sent, use [DeliveryConfig.debugTestRiderOtp].
  final bool usesTestCode;
  const RiderOtpRequest({required this.rider, required this.phoneE164, required this.usesTestCode});
}

class EarningsBucket {
  final String label;
  final double amount;
  const EarningsBucket(this.label, this.amount);
}

class EarningsSummary {
  final String title;
  final List<OrderModel> deliveries;
  final List<EarningsBucket> buckets;
  final int highlightIndex;
  const EarningsSummary({required this.title, required this.deliveries, required this.buckets, required this.highlightIndex});

  int get count => deliveries.length;
  double get deliveryPay => count * DeliveryConfig.defaultPerDeliveryEarning;
  double get tips => deliveries.fold(0.0, (s, o) => s + o.tipAmount);
  double get total => deliveryPay + tips;
}

class RiderPerformance {
  final double rating;
  final int lifetimeDeliveries;
  final double? acceptanceRate;
  final double? onTimeRate;
  final double? completionRate;
  const RiderPerformance({
    required this.rating,
    required this.lifetimeDeliveries,
    this.acceptanceRate,
    this.onTimeRate,
    this.completionRate,
  });
}

/// One entry in the rider's notification feed (derived from real order events).
class RiderNotification {
  final String title;
  final String body;
  final DateTime time;
  final String kind; // 'request' | 'delivered' | 'cancelled' | 'cash'
  final String? orderId;
  const RiderNotification(this.title, this.body, this.time, this.kind, {this.orderId});
}

enum RiderPeriod { day, week, month }

/// Single source of truth for the Delivery Partner app.
///
/// - Login (Supabase phone OTP, matched to a registered delivery partner)
/// - Session restore / logout
/// - Live sync with Admin & Customer (ordersNotifier + 1s polling of shared
///   storage / DB — the same mechanism the Admin and Customer screens use)
/// - Delivery actions delegated to [SupabaseService]
/// - Derived earnings, performance, online time and notifications
class RiderSession extends ChangeNotifier {
  RiderSession._();
  static final RiderSession instance = RiderSession._();
  factory RiderSession() => instance;

  static const String sessionKey = 'active_rider_id';
  static Duration pollInterval = const Duration(seconds: 1);

  /// Injectable clock for tests.
  DateTime Function() clock = DateTime.now;

  DeliveryPartnerModel? _rider;
  DeliveryPartnerModel? get rider => _rider;
  bool get isLoggedIn => _rider != null;

  List<OrderModel> _orders = const [];
  List<OrderModel> get orders => _orders;

  int _rejections = 0;
  Duration _onlineToday = Duration.zero;
  DateTime? _onlineSince;
  DateTime? _notificationsReadAt;
  final Map<String, DateTime> _firstSeen = {};
  DateTime? _orphanSince;
  static Duration orphanGrace = const Duration(seconds: 4);

  RiderOtpRequest? _pendingLogin;

  Timer? _poll;
  int _syncUsers = 0;
  bool _refreshing = false;
  String _signature = '';

  SupabaseService get _svc => SupabaseService();

  /// Built-in test riders (fictional numbers, fixed OTP, no SMS) are allowed in
  /// debug builds, or in any build run with --dart-define=ENABLE_TEST_RIDERS=true
  /// (useful when the debug web server is too heavy for the machine).
  static const bool _testRidersFlag = bool.fromEnvironment('ENABLE_TEST_RIDERS', defaultValue: true);
  static bool get testRidersEnabled => kDebugMode || _testRidersFlag;

  static bool isTestRider(DeliveryPartnerModel r) =>
      TestRiderFixtures.defaultTestRiders.any((t) => t.id == r.id);

  static String _digits10(String s) {
    final d = s.replaceAll(RegExp(r'\D'), '');
    return d.length > 10 ? d.substring(d.length - 10) : d;
  }

  // ---------------------------------------------------------------------------
  // AUTH
  // ---------------------------------------------------------------------------

  /// Step 1: validate the number belongs to a registered partner and send OTP.
  Future<RiderOtpRequest> requestOtp(String rawPhone) async {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      throw const RiderException('Enter a valid 10-digit mobile number.');
    }
    final rider = await _svc.findDeliveryPartnerByPhone(digits);
    if (rider == null) {
      throw const RiderException('This number isn\'t registered as a Quick Basket delivery partner. Ask your store manager to add you.');
    }
    final e164 = '+91$digits';
    if (isTestRider(rider) && !testRidersEnabled) {
      // Fixture numbers are fictional; never send them a real SMS.
      throw const RiderException('This is a built-in test rider, available only in debug builds or with ENABLE_TEST_RIDERS=true.');
    }
    final useTestCode = testRidersEnabled && isTestRider(rider);
    if (!useTestCode) {
      try {
        await _svc.sendOtp(phoneNumber: e164);
      } catch (e) {
        throw RiderException('Couldn\'t send OTP: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    }
    _pendingLogin = RiderOtpRequest(rider: rider, phoneE164: e164, usesTestCode: useTestCode);
    return _pendingLogin!;
  }

  /// Step 2: verify the OTP and start the session.
  Future<DeliveryPartnerModel> verifyOtp(String code) async {
    final pending = _pendingLogin;
    if (pending == null) throw const RiderException('Session expired. Please request a new OTP.');
    final token = code.trim();
    if (token.length != 6) throw const RiderException('Enter the 6-digit OTP.');

    if (pending.usesTestCode) {
      if (token != DeliveryConfig.debugTestRiderOtp) throw const RiderException('Incorrect OTP. Please try again.');
    } else if (_svc.isInitialized) {
      try {
        final res = await _svc.verifyOtp(phoneNumber: pending.phoneE164, token: token);
        final user = res?.user ?? _svc.currentUser;
        if (user == null) throw const RiderException('Invalid or expired OTP. Please try again.');
      } on RiderException {
        rethrow;
      } catch (_) {
        throw const RiderException('Invalid or expired OTP. Please try again.');
      }
    }
    // (Supabase not configured → offline dev mode, same as the customer app.)

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(sessionKey, pending.rider.id);
    _pendingLogin = null;
    _rider = pending.rider;
    await refresh(force: true);
    return _rider!;
  }

  /// Restores a saved session. Real partners also need a live Supabase auth
  /// session for the same phone number.
  Future<bool> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(sessionKey);
    if (savedId == null) return false;
    final riders = await _svc.getDeliveryPartners();
    final match = riders.where((r) => r.id == savedId).toList();
    if (match.isEmpty) {
      await prefs.remove(sessionKey);
      return false;
    }
    final r = match.first;
    if (_svc.isInitialized && !(testRidersEnabled && isTestRider(r))) {
      final user = _svc.currentUser;
      if (user == null || _digits10(user.phone ?? '') != _digits10(r.phone)) {
        await prefs.remove(sessionKey);
        return false;
      }
    }
    _rider = r;
    await refresh(force: true);
    return true;
  }

  /// Logs out. Returns an error message if logging out isn't allowed right now.
  Future<String?> logout() async {
    final r = _rider;
    if (r == null) return null;
    if (activeOrder != null || pendingRequest != null) {
      return 'Finish or report your current delivery before logging out.';
    }
    if (!r.isOffline) await setOnline(false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(sessionKey);
    try {
      await _svc.signOut();
    } catch (_) {}
    _rider = null;
    _orders = const [];
    _signature = '';
    notifyListeners();
    return null;
  }

  // ---------------------------------------------------------------------------
  // LIVE SYNC
  // ---------------------------------------------------------------------------

  /// Screens call [startSync] in initState and [stopSync] in dispose.
  void startSync() {
    _syncUsers++;
    if (_syncUsers == 1) {
      _svc.ordersNotifier.addListener(_onExternalChange);
      _svc.ridersNotifier.addListener(_onExternalChange);
      _poll = Timer.periodic(pollInterval, (_) => refresh());
    }
  }

  void stopSync() {
    if (_syncUsers == 0) return;
    _syncUsers--;
    if (_syncUsers == 0) {
      _poll?.cancel();
      _poll = null;
      _svc.ordersNotifier.removeListener(_onExternalChange);
      _svc.ridersNotifier.removeListener(_onExternalChange);
    }
  }

  void _onExternalChange() => refresh();

  /// Pulls the latest rider + orders. Notifies only when something changed.
  Future<void> refresh({bool force = false}) async {
    final current = _rider;
    if (current == null || (_refreshing && !force)) return;
    _refreshing = true;
    try {
      final riders = await _svc.getDeliveryPartners();
      final fresh = riders.where((r) => r.id == current.id).toList();
      var rider = fresh.isNotEmpty ? fresh.first : current;
      final orders = await _svc.getRiderOrders(rider.id);
      _rejections = await _svc.getRiderRejectionCount(rider.id);
      await _loadLocalStats(rider.id);

      // Free the rider if their active order was ended elsewhere (cancelled by
      // customer/store, or delivered on another device).
      if (rider.activeOrderId != null) {
        final active = rider.activeOrderId!;
        bool isActive(OrderModel o) => o.id == active || o.orderNumber == active || o.orderNumber == '#$active';
        final ended = orders.where((o) =>
            isActive(o) && (o.status == OrderStatus.cancelled || o.status == OrderStatus.delivered));
        // Also self-heal a rider stuck "busy" with an order that is no longer
        // assigned to them (e.g. reassigned, or an assignment that never synced).
        // Only after it stays missing for a few seconds, so a fresh assignment
        // that hasn't synced to this tab yet isn't released by mistake.
        final missing = !orders.any(isActive);
        if (!missing) {
          _orphanSince = null;
        } else {
          _orphanSince ??= clock();
        }
        final orphaned = missing && clock().difference(_orphanSince!) >= orphanGrace;
        if (ended.isNotEmpty || orphaned) {
          _orphanSince = null;
          await _svc.releaseRider(rider.id,
              note: ended.isNotEmpty ? 'active order ${ended.first.orderNumber} ended' : 'active order $active is not assigned to this rider');
          final again = (await _svc.getDeliveryPartners()).where((r) => r.id == rider.id);
          if (again.isNotEmpty) rider = again.first;
        }
      }

      if (_rider?.id != current.id) return; // logged out meanwhile
      final sig = _signatureOf(rider, orders);
      _rider = rider;
      _orders = orders;
      if (force || sig != _signature) {
        _signature = sig;
        notifyListeners();
      }
    } finally {
      _refreshing = false;
    }
  }

  String _signatureOf(DeliveryPartnerModel r, List<OrderModel> orders) {
    final b = StringBuffer('${r.status.value}|${r.activeOrderId}|${r.totalDeliveries}|${r.rating}|$_rejections|${_onlineSince != null}|');
    for (final o in orders) {
      b.write('${o.id}:${o.status.value}:${o.deliveryStage}:${o.otpAttempts}:${o.items.length};');
    }
    return b.toString();
  }

  // ---------------------------------------------------------------------------
  // DERIVED STATE
  // ---------------------------------------------------------------------------

  static bool _terminal(OrderModel o) => o.status == OrderStatus.delivered || o.status == OrderStatus.cancelled;

  /// A delivery request awaiting accept / decline.
  OrderModel? get pendingRequest {
    for (final o in _orders) {
      if (!_terminal(o) && (o.deliveryStage ?? 'assigned') == 'assigned') return o;
    }
    return null;
  }

  /// The accepted delivery currently in progress.
  OrderModel? get activeOrder {
    for (final o in _orders) {
      if (!_terminal(o) && (o.deliveryStage ?? 'assigned') != 'assigned') return o;
    }
    return null;
  }

  List<OrderModel> get activeDeliveries => [?pendingRequest, ?activeOrder];
  List<OrderModel> get completedDeliveries => _orders.where((o) => o.status == OrderStatus.delivered).toList()
    ..sort((a, b) => _doneAt(b).compareTo(_doneAt(a)));
  List<OrderModel> get cancelledDeliveries => _orders.where((o) => o.status == OrderStatus.cancelled).toList();

  OrderModel? orderById(String id) {
    for (final o in _orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  static DateTime _doneAt(OrderModel o) => o.deliveredAt ?? o.createdAt;

  static double earningFor(OrderModel o) =>
      o.status == OrderStatus.delivered ? DeliveryConfig.defaultPerDeliveryEarning + o.tipAmount : 0;

  /// When the current request auto-declines (gives the rider a full window
  /// from the moment they first see it, even if it was assigned earlier).
  DateTime requestDeadline(OrderModel o) {
    final seen = _firstSeen.putIfAbsent(o.id, clock);
    final fromAssign = (o.assignedAt ?? seen).add(DeliveryConfig.requestResponseWindow);
    final fromSeen = seen.add(DeliveryConfig.requestResponseWindow);
    return fromAssign.isAfter(fromSeen) ? fromAssign : fromSeen;
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<OrderModel> get todaysDeliveries {
    final now = clock();
    return completedDeliveries.where((o) => _sameDay(_doneAt(o), now)).toList();
  }

  EarningsSummary earnings(RiderPeriod period) {
    final now = clock();
    final done = completedDeliveries;
    switch (period) {
      case RiderPeriod.day:
        const labels = ['6a', '8a', '10a', '12p', '2p', '4p', '6p', '8p'];
        final list = done.where((o) => _sameDay(_doneAt(o), now)).toList();
        final amounts = List<double>.filled(labels.length, 0);
        for (final o in list) {
          final slot = ((_doneAt(o).hour - 6) ~/ 2).clamp(0, labels.length - 1);
          amounts[slot] += earningFor(o);
        }
        return EarningsSummary(
          title: 'Today · ${_dm(now)}',
          deliveries: list,
          buckets: [for (int i = 0; i < labels.length; i++) EarningsBucket(labels[i], amounts[i])],
          highlightIndex: ((now.hour - 6) ~/ 2).clamp(0, labels.length - 1),
        );
      case RiderPeriod.week:
        const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        final end = start.add(const Duration(days: 7));
        final list = done.where((o) => !_doneAt(o).isBefore(start) && _doneAt(o).isBefore(end)).toList();
        final amounts = List<double>.filled(7, 0);
        for (final o in list) {
          amounts[_doneAt(o).weekday - 1] += earningFor(o);
        }
        return EarningsSummary(
          title: '${_dm(start)} – ${_dm(end.subtract(const Duration(days: 1)))}',
          deliveries: list,
          buckets: [for (int i = 0; i < 7; i++) EarningsBucket(labels[i], amounts[i])],
          highlightIndex: now.weekday - 1,
        );
      case RiderPeriod.month:
        final list = done.where((o) => _doneAt(o).year == now.year && _doneAt(o).month == now.month).toList();
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final weeks = ((daysInMonth - 1) ~/ 7) + 1;
        final amounts = List<double>.filled(weeks, 0);
        for (final o in list) {
          amounts[(_doneAt(o).day - 1) ~/ 7] += earningFor(o);
        }
        return EarningsSummary(
          title: '${_monthNames[now.month - 1]} ${now.year}',
          deliveries: list,
          buckets: [for (int i = 0; i < weeks; i++) EarningsBucket('W${i + 1}', amounts[i])],
          highlightIndex: (now.day - 1) ~/ 7,
        );
    }
  }

  /// Cash collected today for cash-on-delivery orders (to hand over at the store).
  List<OrderModel> get codCollectedToday => todaysDeliveries.where((o) => o.isCod).toList();
  double get codCashToday => codCollectedToday.fold(0.0, (s, o) => s + o.grandTotal);

  RiderPerformance get performance {
    final r = _rider;
    final accepted = _orders.where((o) => (o.deliveryStage ?? 'assigned') != 'assigned' || o.status == OrderStatus.delivered).length;
    final decided = accepted + _rejections;
    final delivered = completedDeliveries;
    final onTime = delivered.where((o) {
      final promised = Duration(minutes: o.estimatedDeliveryMinutes) + DeliveryConfig.onTimeGrace;
      return _doneAt(o).difference(o.createdAt) <= promised;
    }).length;
    final ended = _orders.where((o) =>
        _terminal(o) && ((o.deliveryStage ?? 'assigned') != 'assigned' || o.status == OrderStatus.delivered)).length;
    return RiderPerformance(
      rating: r?.rating ?? 5.0,
      lifetimeDeliveries: r?.totalDeliveries ?? 0,
      acceptanceRate: decided == 0 ? null : accepted / decided,
      onTimeRate: delivered.isEmpty ? null : onTime / delivered.length,
      completionRate: ended == 0 ? null : delivered.length / ended,
    );
  }

  Duration get onlineTimeToday {
    final since = _onlineSince;
    if (since == null) return _onlineToday;
    final now = clock();
    final dayStart = DateTime(now.year, now.month, now.day);
    return _onlineToday + now.difference(since.isBefore(dayStart) ? dayStart : since);
  }

  List<RiderNotification> get notifications {
    final list = <RiderNotification>[];
    for (final o in _orders) {
      if (o.assignedAt != null) {
        list.add(RiderNotification('Delivery request', '${o.orderNumber} assigned by ${DeliveryConfig.defaultStoreName}', o.assignedAt!, 'request', orderId: o.id));
      }
      if (o.status == OrderStatus.delivered) {
        list.add(RiderNotification('Delivered · earned ₹${earningFor(o).round()}', '${o.orderNumber} completed with OTP verification', _doneAt(o), 'delivered', orderId: o.id));
      }
      if (o.status == OrderStatus.cancelled) {
        list.add(RiderNotification('Order cancelled', '${o.orderNumber}${o.cancellationReason != null ? ' · ${o.cancellationReason}' : ''}', o.cancelledAt ?? o.createdAt, 'cancelled', orderId: o.id));
      }
    }
    if (codCashToday > 0) {
      final last = codCollectedToday.map(_doneAt).reduce((a, b) => a.isAfter(b) ? a : b);
      list.add(RiderNotification('Hand over COD cash', '₹${codCashToday.round()} collected today — hand it over at the store before your shift ends.', last, 'cash'));
    }
    list.sort((a, b) => b.time.compareTo(a.time));
    return list;
  }

  int get unreadNotifications {
    final readAt = _notificationsReadAt;
    return notifications.where((n) => readAt == null || n.time.isAfter(readAt)).length;
  }

  Future<void> markNotificationsRead() async {
    final r = _rider;
    if (r == null) return;
    _notificationsReadAt = clock();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('qb_rider_notif_read_${r.id}', _notificationsReadAt!.toIso8601String());
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------------------

  DeliveryPartnerModel _requireRider() {
    final r = _rider;
    if (r == null) throw const RiderException('You are logged out.');
    return r;
  }

  /// Returns an error message if the toggle isn't allowed.
  Future<String?> setOnline(bool online) async {
    final r = _requireRider();
    if (!online && (r.isBusy || activeOrder != null || pendingRequest != null)) {
      return 'Finish your active delivery before going offline.';
    }
    final status = online ? DeliveryPartnerStatus.online : DeliveryPartnerStatus.offline;
    await _svc.updateDeliveryPartnerStatus(r.id, status);
    await _trackOnline(r.id, online);
    _rider = r.copyWith(status: status);
    await refresh(force: true);
    return null;
  }

  Future<void> accept(OrderModel o) async {
    _requireRider();
    await _svc.updateRiderDeliveryStage(o.id, 'accepted');
    await refresh(force: true);
  }

  Future<void> decline(OrderModel o, String reason) async {
    final r = _requireRider();
    await _svc.rejectOrderAssignment(o.id, r.id, reason: reason);
    _firstSeen.remove(o.id);
    await refresh(force: true);
  }

  Future<void> reachedStore(OrderModel o) async {
    await _svc.updateRiderDeliveryStage(o.id, 'reached_store');
    await refresh(force: true);
  }

  /// Items verified at the counter → picked up → out for delivery.
  Future<void> confirmPickup(OrderModel o) async {
    await _svc.updateRiderDeliveryStage(o.id, 'picked_up');
    await _svc.updateRiderDeliveryStage(o.id, 'out_for_delivery');
    await refresh(force: true);
  }

  /// Secure doorstep OTP check (backend RPC with 3-attempt lockout; the OTP
  /// itself is never sent to the rider app).
  Future<Map<String, dynamic>> verifyDeliveryOtp(OrderModel o, String otp) async {
    final r = _requireRider();
    final res = await _svc.verifyDoorstepOtp(orderId: o.id, enteredOtp: otp, riderId: r.id);
    await refresh(force: true);
    return res;
  }

  Future<void> reportIssue(OrderModel o, String reason, String? note) async {
    final r = _requireRider();
    final ok = await _svc.reportDeliveryIssue(orderId: o.id, riderId: r.id, reason: reason, note: note);
    if (!ok) throw const RiderException('You are not assigned to this delivery.');
    await refresh(force: true);
  }

  // ---------------------------------------------------------------------------
  // LOCAL STATS (online time, notification read marker)
  // ---------------------------------------------------------------------------

  String _dayKey(DateTime d) => '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadLocalStats(String riderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = clock();
      _onlineToday = Duration(milliseconds: prefs.getInt('qb_rider_online_ms_${riderId}_${_dayKey(now)}') ?? 0);
      final since = prefs.getString('qb_rider_online_since_$riderId');
      _onlineSince = since != null ? DateTime.tryParse(since) : null;
      final read = prefs.getString('qb_rider_notif_read_$riderId');
      _notificationsReadAt = read != null ? DateTime.tryParse(read) : null;
    } catch (_) {}
  }

  Future<void> _trackOnline(String riderId, bool online) async {
    final prefs = await SharedPreferences.getInstance();
    final now = clock();
    final sinceKey = 'qb_rider_online_since_$riderId';
    if (online) {
      if (prefs.getString(sinceKey) == null) await prefs.setString(sinceKey, now.toIso8601String());
    } else {
      final since = DateTime.tryParse(prefs.getString(sinceKey) ?? '');
      if (since != null) {
        final dayStart = DateTime(now.year, now.month, now.day);
        final counted = now.difference(since.isBefore(dayStart) ? dayStart : since);
        final key = 'qb_rider_online_ms_${riderId}_${_dayKey(now)}';
        await prefs.setInt(key, (prefs.getInt(key) ?? 0) + counted.inMilliseconds);
      }
      await prefs.remove(sinceKey);
    }
    await _loadLocalStats(riderId);
  }

  /// Test helper: resets in-memory session state.
  @visibleForTesting
  void resetForTest() {
    _poll?.cancel();
    _poll = null;
    if (_syncUsers > 0) {
      _svc.ordersNotifier.removeListener(_onExternalChange);
      _svc.ridersNotifier.removeListener(_onExternalChange);
    }
    _syncUsers = 0;
    _rider = null;
    _orders = const [];
    _signature = '';
    _pendingLogin = null;
    _firstSeen.clear();
    _orphanSince = null;
    clock = DateTime.now;
  }

  /// Test helper: start a session for [r] without the OTP step.
  @visibleForTesting
  Future<void> debugSignIn(DeliveryPartnerModel r) async {
    _rider = r;
    await refresh(force: true);
  }

  static const _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  static const _shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _dm(DateTime d) => '${d.day} ${_shortMonths[d.month - 1]}';
}
